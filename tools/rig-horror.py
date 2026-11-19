#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Скелет Mixamo для моделей хоррор-врагов «5 НОЧЕЙ С ПАХАНОМ», у которых его нет (статичная сетка с сайта Tripo).

    python tools/rig-horror.py <id> <статичная.glb> <выход.glb> [--template=<модель со скелетом.glb>]

Что делает:
  * берёт скелет у модели, на которой враг ходил раньше (godot/assets/models/<шаблон>.glb): те же 65 костей mixamorig:*,
    те же оси и та же поза покоя — поэтому готовые анимации врага (FNPoses) ложатся без правок;
  * суставы ставит по разметке модели (RIGS ниже: координаты в «единицах модели» — 1 = наибольшая сторона, начало —
    центр основания, +Z — лицо, +X — левая рука персонажа; сняты с ортогональных видов);
  * привязка сетки (bind) — по настоящему положению рук и ног модели, покой скелета — стандартный: в игре в покое
    руки модели встают как у остальных персонажей, и поза «рука вверх» значит то же, что у всех; у кого так нельзя
    (широкие рукава призрака рвались бы, ноги «коленом назад») — align < 1: покой ближе к вылепленной позе;
  * веса — по частям тела: туловище, голова, руки, ноги (правила parts / head / fixed), внутри цепочки костей —
    плавный переход у суставов. Аниматроники жёсткие, так и задумано;
  * сетка с сайта — одна сплошная оболочка: где кисть касалась головы, а рукав — подола, они срослись. Треугольники,
    соединяющие далёкие по скелету части (дальше двух костей друг от друга), вырезаются — иначе при движении между
    рукой и головой тянется плёнка.
Сетка, текстуры и материал модели не меняются. Зависимостей нет (чистый Python).
"""
import json, math, struct, sys, os

# ----------------------------------------------------------------------------- математика (3×3 по строкам, векторы)
def v_add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def v_sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def v_mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def v_dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def v_cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def v_len(a): return math.sqrt(v_dot(a, a))
def v_norm(a):
    l = v_len(a)
    return (a[0] / l, a[1] / l, a[2] / l) if l > 1e-12 else (0.0, 1.0, 0.0)

I3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
def m_mul(A, B): return tuple(tuple(sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)) for i in range(3))
def m_vec(A, v): return tuple(A[i][0] * v[0] + A[i][1] * v[1] + A[i][2] * v[2] for i in range(3))
def m_T(A): return tuple(tuple(A[j][i] for j in range(3)) for i in range(3))
def m_inv(A):
    a, b, c = A[0]; d, e, f = A[1]; g, h, i = A[2]
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    return tuple(tuple(x / det for x in r) for r in (
        (e * i - f * h, c * h - b * i, b * f - c * e),
        (f * g - d * i, a * i - c * g, c * d - a * f),
        (d * h - e * g, b * g - a * h, a * e - b * d)))

def rot_between(a, b, k=1.0):
    """наименьший поворот, переводящий a в b; k < 1 — только доля этого поворота"""
    a = v_norm(a); b = v_norm(b)
    c = v_dot(a, b)
    if c > 0.999999:
        return I3
    if c < -0.999999:
        ax = v_norm(v_cross(a, (1, 0, 0) if abs(a[0]) < 0.9 else (0, 1, 0)))
        return rot_axis(ax, math.pi * k)
    ax = v_norm(v_cross(a, b))
    return rot_axis(ax, math.acos(max(-1.0, min(1.0, c))) * k)

def rot_axis(ax, ang):
    x, y, z = ax; c = math.cos(ang); s = math.sin(ang); t = 1 - c
    return ((t * x * x + c, t * x * y - s * z, t * x * z + s * y),
            (t * x * y + s * z, t * y * y + c, t * y * z - s * x),
            (t * x * z - s * y, t * y * z + s * x, t * z * z + c))

# преобразование = (M 3×3, t)
def x_mul(A, B): return (m_mul(A[0], B[0]), v_add(m_vec(A[0], B[1]), A[1]))
def x_inv(A):
    Mi = m_inv(A[0])
    return (Mi, v_mul(m_vec(Mi, A[1]), -1.0))
def x_from_gltf(m): return (((m[0], m[4], m[8]), (m[1], m[5], m[9]), (m[2], m[6], m[10])), (m[12], m[13], m[14]))
def x_to_gltf(A):
    M, t = A
    return [M[0][0], M[1][0], M[2][0], 0.0, M[0][1], M[1][1], M[2][1], 0.0, M[0][2], M[1][2], M[2][2], 0.0, t[0], t[1], t[2], 1.0]
XI = (I3, (0.0, 0.0, 0.0))

def quat_to_m(q):
    x, y, z, w = q
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
            (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
            (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)))

def node_local(n):
    if 'matrix' in n:
        return x_from_gltf(n['matrix'])
    M = quat_to_m(n.get('rotation', [0, 0, 0, 1]))
    s = n.get('scale', [1, 1, 1])
    M = tuple(tuple(M[i][j] * s[j] for j in range(3)) for i in range(3))
    return (M, tuple(n.get('translation', [0, 0, 0])))

# ----------------------------------------------------------------------------- glb
def read_glb(path):
    raw = open(path, 'rb').read()
    jlen = struct.unpack_from('<I', raw, 12)[0]
    # целые, записанные как «3.0» (так пишет glbslim.gd), читаем целыми
    j = json.loads(raw[20:20 + jlen].decode('utf-8'), parse_float=lambda t: int(float(t)) if float(t).is_integer() else float(t))
    blen = struct.unpack_from('<I', raw, 20 + jlen)[0]
    return j, raw[28 + jlen:28 + jlen + blen]

def acc_bytes(j, bin_, ai):
    a = j['accessors'][ai]
    bv = j['bufferViews'][a['bufferView']]
    comp = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[a['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    stride = bv.get('byteStride', comp * n)
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    if stride == comp * n:
        return bin_[off:off + comp * n * a['count']], a
    return b''.join(bin_[off + i * stride:off + i * stride + comp * n] for i in range(a['count'])), a

# ----------------------------------------------------------------------------- разметка моделей
def sm(a, b, x):
    """smoothstep"""
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def mod_e(x, y, z):
    """MOD: «радиус» точки относительно головы-эллипсоида (1 — поверхность; голова чуть угловатая, запас — до 1,12)"""
    return math.sqrt(((x - 0.0625) / 0.365) ** 2 + ((y - 0.695) / 0.318) ** 2 + ((z + 0.012) / 0.34) ** 2)

RIGS = {
    # БАЛОН: баллон — тело и голова разом, поэтому он жёсткий и слушается сразу двух костей (грудь и голова)
    'balon': {
        'template': 'bot', 'band': 0.02, 'align': {'arm': 1.0, 'leg': 1.0},
        'spine': [(0.014, 0.24, 0.0), (0.014, 0.35, 0.0), (0.014, 0.45, 0.0), (0.014, 0.55, 0.0), (0.014, 0.62, 0.0), (0.014, 0.66, 0.0), (0.014, 0.98, 0.0)],
        'L': {'sh': (0.12, 0.40, 0.0), 'arm': (0.205, 0.394, 0.02), 'elbow': (0.273, 0.375, 0.08), 'wrist': (0.352, 0.43, 0.12), 'tip': (0.47, 0.44, 0.16),
              'hip': (0.105, 0.225, 0.02), 'knee': (0.115, 0.14, 0.04), 'ankle': (0.125, 0.07, -0.04), 'toe': (0.135, 0.02, 0.08), 'toe_end': (0.135, 0.02, 0.12)},
        'R': {'sh': (-0.10, 0.40, 0.0), 'arm': (-0.195, 0.394, 0.02), 'elbow': (-0.25, 0.375, 0.08), 'wrist': (-0.336, 0.42, 0.12), 'tip': (-0.46, 0.44, 0.16),
              'hip': (-0.078, 0.225, 0.02), 'knee': (-0.10, 0.14, 0.04), 'ankle': (-0.10, 0.07, -0.04), 'toe': (-0.11, 0.02, 0.08), 'toe_end': (-0.11, 0.02, 0.12)},
        'fixed': lambda x, y, z, H: ({'Spine2': 0.6, 'Head': 0.4} if y > 0.212 and (math.hypot(x - 0.014, z) < 0.2 or (math.hypot(x - 0.014, z) < 0.235 and abs(x - 0.014) < 0.165)) else None),
        'part': lambda x, y, z, H: ('armL' if x > 0 else 'armR') if y > 0.3 else ('legL' if x > 0.014 else 'legR'),
        'head': lambda x, y, z, H: 0.0,
        'eyes': {'pos': (0.016, 0.586, 0.19), 'sep': 0.14, 'r': 0.022},
    },
    'madk1d': {
        'template': 'madk1d', 'band': 0.03, 'align': {'arm': 1.0, 'leg': 1.0},
        'spine': [(0.0, 0.27, -0.03), (0.0, 0.32, -0.03), (0.0, 0.37, -0.03), (0.0, 0.42, -0.03), (0.0, 0.49, -0.02), (0.0, 0.53, 0.0), (0.0, 0.98, 0.0)],
        'L': {'sh': (0.05, 0.445, -0.03), 'arm': (0.097, 0.4375, -0.03), 'elbow': (0.164, 0.403, 0.0), 'wrist': (0.227, 0.378, 0.04), 'tip': (0.31, 0.29, 0.08),
              'hip': (0.0625, 0.25, -0.02), 'knee': (0.07, 0.19, -0.01), 'ankle': (0.078, 0.133, 0.0), 'toe': (0.105, 0.03, 0.09), 'toe_end': (0.11, 0.03, 0.14)},
        'R': {'sh': (-0.05, 0.445, -0.03), 'arm': (-0.094, 0.4375, -0.03), 'elbow': (-0.156, 0.398, 0.0), 'wrist': (-0.227, 0.375, 0.04), 'tip': (-0.305, 0.28, 0.08),
              'hip': (-0.078, 0.25, -0.02), 'knee': (-0.078, 0.19, -0.01), 'ankle': (-0.086, 0.133, 0.0), 'toe': (-0.112, 0.03, 0.09), 'toe_end': (-0.117, 0.03, 0.14)},
        'fixed': lambda x, y, z, H: None,
        'part': lambda x, y, z, H: ('armL' if x > 0 else 'armR') if (0.25 < y < 0.50 and (abs(x) > 0.118 or (abs(x) > 0.08 and H.arm(x, y, z) < 0.04))) else (('legL' if x > -0.008 else 'legR') if y < 0.235 else None),
        'head': lambda x, y, z, H: sm(0.488, 0.515, y),
        'eyes': {'pos': (-0.004, 0.66, 0.175), 'sep': 0.164, 'r': 0.02},
    },
    'bot': {
        'template': 'bot', 'band': 0.025, 'align': {'arm': 1.0, 'leg': 1.0},
        'spine': [(0.0, 0.28, 0.0), (0.0, 0.33, 0.0), (0.0, 0.38, 0.0), (0.0, 0.42, 0.0), (0.0, 0.465, 0.0), (0.0, 0.50, 0.0), (0.0, 1.0, 0.0)],
        'L': {'sh': (0.05, 0.44, 0.0), 'arm': (0.097, 0.43, 0.0), 'elbow': (0.195, 0.42, 0.01), 'wrist': (0.297, 0.427, 0.03), 'tip': (0.43, 0.40, 0.05),
              'hip': (0.047, 0.273, 0.0), 'knee': (0.125, 0.1875, 0.055), 'ankle': (0.172, 0.07, 0.0), 'toe': (0.195, 0.02, 0.08), 'toe_end': (0.2, 0.02, 0.12)},
        'R': {'sh': (-0.05, 0.44, 0.0), 'arm': (-0.10, 0.4375, 0.0), 'elbow': (-0.21, 0.4375, 0.01), 'wrist': (-0.305, 0.44, 0.03), 'tip': (-0.43, 0.46, 0.05),
              'hip': (-0.055, 0.273, 0.0), 'knee': (-0.117, 0.172, 0.055), 'ankle': (-0.117, 0.07, 0.0), 'toe': (-0.15, 0.02, 0.08), 'toe_end': (-0.156, 0.02, 0.12)},
        'fixed': lambda x, y, z, H: None,
        'part': lambda x, y, z, H: ('armL' if x > 0 else 'armR') if ((abs(x) > 0.095 and 0.36 < y < 0.48 and z > -0.07) or (abs(x) > 0.24 and y < 0.58)) else (('legL' if x > 0 else 'legR') if y < 0.265 and z > -0.085 else None),
        'head': lambda x, y, z, H: sm(0.468, 0.488, y) if z > -0.075 or y > 0.5 else 0.0,
        'eyes': {'pos': (-0.019, 0.68, 0.155), 'sep': 0.118, 'r': 0.018},
    },
    # CLIPPER: сгорбленный, ноги «коленом назад» — спина и ноги остаются как вылеплены, руки приводятся к стандарту
    'clipper': {
        'template': 'clipper', 'band': 0.02, 'align': {'arm': 1.0},
        'spine': [(0.0, 0.47, -0.2), (0.0, 0.55, -0.17), (0.0, 0.63, -0.12), (0.0, 0.72, -0.06), (0.0, 0.82, 0.05), (0.0, 0.86, 0.15), (0.0, 0.99, 0.2)],
        'L': {'sh': (0.13, 0.76, -0.06), 'arm': (0.242, 0.74, -0.06), 'elbow': (0.33, 0.61, -0.02), 'wrist': (0.406, 0.406, 0.05), 'tip': (0.44, 0.25, 0.1),
              'hip': (0.094, 0.47, -0.2), 'knee': (0.1875, 0.28, -0.03), 'ankle': (0.156, 0.10, -0.22), 'toe': (0.21, 0.02, -0.04), 'toe_end': (0.22, 0.02, 0.01)},
        'R': {'sh': (-0.13, 0.76, -0.06), 'arm': (-0.24, 0.74, -0.06), 'elbow': (-0.29, 0.54, -0.02), 'wrist': (-0.365, 0.38, 0.07), 'tip': (-0.44, 0.12, 0.22),
              'hip': (-0.094, 0.47, -0.2), 'knee': (-0.2, 0.28, -0.03), 'ankle': (-0.17, 0.11, -0.22), 'toe': (-0.24, 0.02, -0.04), 'toe_end': (-0.25, 0.02, 0.01)},
        'fixed': lambda x, y, z, H: None,
        'part': lambda x, y, z, H: ('armL' if x > 0 else 'armR') if ((abs(x) > 0.19 and y >= 0.47) or (abs(x) > 0.19 and H.arm(x, y, z) < H.leg(x, y, z))) else (('legL' if x > 0 else 'legR') if y < 0.42 else None),
        'head': lambda x, y, z, H: sm(0.07, 0.10, z) if y > 0.74 else 0.0,
        'eyes': {'pos': (0.0, 0.867, 0.285), 'sep': 0.0, 'r': 0.03},
    },
    'ghost': {
        'template': 'hater', 'band': 0.045, 'align': {'arm': 0.3, 'leg': 1.0},
        'spine': [(0.0, 0.36, -0.03), (0.0, 0.44, -0.03), (0.0, 0.52, -0.03), (0.0, 0.60, -0.03), (0.0, 0.69, -0.02), (0.0, 0.73, 0.0), (0.0, 0.99, 0.0)],
        'L': {'sh': (0.05, 0.665, -0.02), 'arm': (0.11, 0.66, -0.02), 'elbow': (0.21, 0.65, 0.02), 'wrist': (0.31, 0.645, 0.05), 'tip': (0.40, 0.565, 0.1),
              'hip': (0.07, 0.34, -0.01), 'knee': (0.086, 0.227, 0.02), 'ankle': (0.11, 0.047, 0.0), 'toe': (0.16, 0.015, 0.09), 'toe_end': (0.17, 0.015, 0.125)},
        'R': {'sh': (-0.05, 0.665, -0.02), 'arm': (-0.11, 0.66, -0.02), 'elbow': (-0.21, 0.645, 0.02), 'wrist': (-0.31, 0.64, 0.05), 'tip': (-0.385, 0.57, 0.1),
              'hip': (-0.07, 0.34, -0.01), 'knee': (-0.086, 0.227, 0.02), 'ankle': (-0.11, 0.047, 0.0), 'toe': (-0.16, 0.015, 0.09), 'toe_end': (-0.17, 0.015, 0.125)},
        'fixed': lambda x, y, z, H: None,
        # рукава с лохмотьями — рука, даже когда висят до колен; подол балахона — таз, ниже подола — ноги
        'part': lambda x, y, z, H: ('armL' if x > 0 else 'armR') if (abs(x) > 0.10 and y > 0.15) else (('legL' if x > 0 else 'legR') if y < 0.30 else None),
        'mix': lambda x, y, z, H, part: sm(0.10, 0.19, abs(x)) if part.startswith('arm') else 1.0 - sm(0.22, 0.30, y),
        'arm_band': 0.09,
        'head': lambda x, y, z, H: sm(0.69, 0.72, y) if abs(x) < 0.17 else 0.0,
        'eyes': {'pos': (0.002, 0.812, 0.105), 'sep': 0.09, 'r': 0.012},
    },
    # MOD: огромная голова-шар, руки вытянуты вперёд, в правой — молоток (весь на кисти)
    'mod': {
        'template': 'bot', 'band': 0.025, 'align': {'arm': 0.0, 'leg': 1.0},     # руки остаются как вылеплены: молоток у головы, палец вперёд
        'spine': [(0.047, 0.21, -0.02), (0.047, 0.25, -0.02), (0.047, 0.29, -0.02), (0.047, 0.33, -0.02), (0.047, 0.375, -0.01), (0.047, 0.40, -0.01), (0.047, 0.99, -0.01)],
        'L': {'sh': (0.12, 0.355, -0.01), 'arm': (0.1875, 0.35, 0.0), 'elbow': (0.266, 0.328, 0.05), 'wrist': (0.3125, 0.3125, 0.1), 'tip': (0.47, 0.33, 0.18),
              'hip': (0.11, 0.1875, -0.01), 'knee': (0.14, 0.125, 0.0), 'ankle': (0.17, 0.07, 0.0), 'toe': (0.24, 0.02, 0.11), 'toe_end': (0.25, 0.02, 0.15)},
        'R': {'sh': (-0.02, 0.355, -0.01), 'arm': (-0.086, 0.35, 0.0), 'elbow': (-0.17, 0.3125, 0.07), 'wrist': (-0.227, 0.273, 0.15), 'tip': (-0.25, 0.22, 0.2),
              'hip': (-0.023, 0.1875, -0.01), 'knee': (-0.04, 0.125, 0.0), 'ankle': (-0.055, 0.07, 0.0), 'toe': (-0.10, 0.02, 0.11), 'toe_end': (-0.11, 0.02, 0.15)},
        'fixed': lambda x, y, z, H: ({'RightHand': 1.0} if (0.1 < y < 0.51 and mod_e(x, y, z) > 1.12 and (x < -0.2 or (x < -0.1 and (y < 0.262 or y > 0.37) and z > 0.1))) else None),
        'part': lambda x, y, z, H: ('armL' if x > 0.047 else 'armR') if (mod_e(x, y, z) > 1.12 and ((abs(x - 0.047) > 0.125 and 0.2 < y < 0.40) or (x > 0.3 and 0.2 < y < 0.46))) else (('legL' if x > 0.047 else 'legR') if y < 0.2 else None),
        # рукава сверху срослись с головой: у самой головы плечо слушается туловища, иначе при взмахе тянется плёнка
        'mix': lambda x, y, z, H, part: (1.0 - sm(0.315, 0.38, y)) if (part.startswith('arm') and abs(x - 0.047) < 0.27) else 1.0,
        'head': lambda x, y, z, H: sm(0.372, 0.395, y),
        'eyes': {'pos': (0.055, 0.586, 0.31), 'sep': 0.25, 'r': 0.03},
    },
}

ARM = ['Shoulder', 'Arm', 'ForeArm', 'Hand']
LEG = ['UpLeg', 'Leg', 'Foot', 'ToeBase']
SPINE = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head']
AIM = {'Arm': 'ForeArm', 'ForeArm': 'Hand', 'Hand': 'HandMiddle1', 'UpLeg': 'Leg', 'Leg': 'Foot', 'Foot': 'ToeBase', 'ToeBase': 'Toe_End'}

def seg_closest(p, a, b):
    ab = v_sub(b, a)
    l2 = v_dot(ab, ab)
    t = 0.0 if l2 < 1e-12 else max(0.0, min(1.0, v_dot(v_sub(p, a), ab) / l2))
    q = v_add(a, v_mul(ab, t))
    return v_len(v_sub(p, q)), t, math.sqrt(l2)

def chain_weights(p, pts, bones, prev_bone, band):
    """вес по цепочке костей: ближайшее звено, у суставов — плавный переход к соседней кости"""
    best = (1e9, 0, 0.0, 1.0)
    for i in range(len(bones)):
        d, t, ln = seg_closest(p, pts[i], pts[i + 1])
        if d < best[0]:
            best = (d, i, t, ln)
    d, i, t, ln = best
    s = t * ln
    w = {bones[i]: 1.0}
    prev = bones[i - 1] if i > 0 else prev_bone
    if prev is not None and s < band:
        k = 0.5 * (1.0 - s / band)
        w[bones[i]] -= k
        w[prev] = w.get(prev, 0.0) + k
    elif i + 1 < len(bones) and (ln - s) < band:
        k = 0.5 * (1.0 - (ln - s) / band)
        w[bones[i]] -= k
        w[bones[i + 1]] = w.get(bones[i + 1], 0.0) + k
    return w, d

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    rid, src, dst = args[0], args[1], args[2]
    R = RIGS[rid]
    here = os.path.dirname(os.path.abspath(__file__))
    tpath = opts.get('template', os.path.join(here, '..', 'godot', 'assets', 'models', R['template'] + '.glb'))
    tj, _tb = read_glb(tpath)
    mj, mb = read_glb(src)

    # ---- шаблон: мировые преобразования узлов
    nodes = tj['nodes']
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get('children', []):
            parent[c] = i
    G = {}
    def glob(i):
        if i not in G:
            L = node_local(nodes[i])
            G[i] = x_mul(glob(parent[i]), L) if i in parent else L
        return G[i]
    for i in range(len(nodes)):
        glob(i)
    skin = tj['skins'][0]
    joints = skin['joints']
    name_of = {i: nodes[i].get('name', '').replace('mixamorig:', '') for i in joints}
    idx = {name_of[i]: i for i in joints}
    jslot = {i: k for k, i in enumerate(joints)}
    mesh_node = next(i for i, n in enumerate(nodes) if 'mesh' in n)
    TP = {nm: G[idx[nm]][1] for nm in idx}                  # мировые места суставов шаблона
    TB = {}
    for nm in idx:                                          # мировые оси костей шаблона (без масштаба)
        M = G[idx[nm]][0]
        cols = [v_norm((M[0][c], M[1][c], M[2][c])) for c in range(3)]
        TB[nm] = ((cols[0][0], cols[1][0], cols[2][0]), (cols[0][1], cols[1][1], cols[2][1]), (cols[0][2], cols[1][2], cols[2][2]))
    # куда смотрит шаблон и где у него лево
    toe = v_sub(TP['LeftToeBase'], TP['LeftFoot'])
    left = v_sub(TP['LeftArm'], TP['RightArm'])
    left = v_norm((left[0], 0.0, left[2]))
    up = (0.0, 1.0, 0.0)
    fwd = v_cross(left, up)                                 # носки бывают развёрнуты — лицо считаем от плеч
    if v_dot(fwd, toe) < 0.0:
        fwd = v_mul(fwd, -1.0)
    # модель: +X — лево персонажа, +Y — верх, +Z — лицо → мир шаблона
    Rw = ((left[0], up[0], fwd[0]), (left[1], up[1], fwd[1]), (left[2], up[2], fwd[2]))
    theight = max(p[1] for p in TP.values()) - min(p[1] for p in TP.values())
    print('RIG %s: шаблон %s — лицо %s, лево %s, рост скелета %.3f' % (rid, R['template'], tuple(round(x, 2) for x in fwd), tuple(round(x, 2) for x in left), theight))

    # ---- сетка модели
    prim = mj['meshes'][0]['primitives'][0]
    pos_b, pos_a = acc_bytes(mj, mb, prim['attributes']['POSITION'])
    nrm_b, _ = acc_bytes(mj, mb, prim['attributes']['NORMAL'])
    uv_b, uv_a = acc_bytes(mj, mb, prim['attributes']['TEXCOORD_0'])
    idx_b, idx_a = acc_bytes(mj, mb, prim['indices'])
    n = pos_a['count']
    P = struct.unpack('<%df' % (n * 3), pos_b)
    N = struct.unpack('<%df' % (n * 3), nrm_b)
    lo, hi = pos_a['min'], pos_a['max']
    unit = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    cx, cz = (lo[0] + hi[0]) * 0.5, (lo[2] + hi[2]) * 0.5
    def to_units(k):
        return ((P[k * 3] - cx) / unit, (P[k * 3 + 1] - lo[1]) / unit, (P[k * 3 + 2] - cz) / unit)

    # ---- суставы модели (единицы модели → мир)
    J = {}
    sp = R['spine']
    for k, nm in enumerate(['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head', 'HeadTop_End']):
        J[nm] = sp[k]
    for side, S in (('Left', R['L']), ('Right', R['R'])):
        J[side + 'Shoulder'] = S['sh']; J[side + 'Arm'] = S['arm']; J[side + 'ForeArm'] = S['elbow']; J[side + 'Hand'] = S['wrist']
        J[side + 'UpLeg'] = S['hip']; J[side + 'Leg'] = S['knee']; J[side + 'Foot'] = S['ankle']; J[side + 'ToeBase'] = S['toe']; J[side + 'Toe_End'] = S['toe_end']
    tips = {'LeftHand': R['L']['tip'], 'RightHand': R['R']['tip']}
    W = lambda p: m_vec(Rw, p)
    Pb = {nm: W(p) for nm, p in J.items()}                  # места суставов в позе привязки
    # ---- оси костей в позе привязки
    B = {}
    order = []                                              # суставы в порядке «родитель раньше ребёнка»
    def walk(i):
        if i in jslot:
            order.append(name_of[i])
        for c in nodes[i].get('children', []):
            walk(c)
    walk(tj['scenes'][0]['nodes'][0])
    par_name = {nm: (name_of[parent[idx[nm]]] if parent.get(idx[nm]) in jslot else None) for nm in order}
    align = R['align']
    def is_aligned(nm):
        """насколько кость приводится к стандартной позе покоя: 1 — полностью, 0 — остаётся как вылеплена"""
        base = nm.replace('Left', '').replace('Right', '')
        if base in ('Arm', 'ForeArm', 'Hand'):
            return align.get('arm', 0.0)
        if base in ('UpLeg', 'Leg', 'Foot', 'ToeBase'):
            return align.get('leg', 0.0)
        return 0.0
    X = {}                                                  # поворот «шаблон → модель» у каждой кости
    for nm in order:
        side = 'Left' if nm.startswith('Left') else ('Right' if nm.startswith('Right') else '')
        base = nm[len(side):]
        pn = par_name[nm]
        if nm not in Pb:                                    # пальцы и прочее — как у родителя
            k = 1.0
            if 'Hand' in nm and side:
                k = v_len(v_sub(W(tips[side + 'Hand']), Pb[side + 'Hand'])) / max(1e-6, v_len(v_sub(TP[side + 'HandMiddle1'], TP[side + 'Hand']))) * 0.45
            X[nm] = X[pn]
            Pb[nm] = v_add(Pb[pn], v_mul(m_vec(X[pn], v_sub(TP[nm], TP[pn])), k))
        elif is_aligned(nm) > 0.0 and base in AIM:
            aim = side + AIM[base]
            target = W(tips[nm]) if base == 'Hand' else Pb[aim]
            X[nm] = rot_between(v_sub(TP[aim], TP[nm]), v_sub(target, Pb[nm]), is_aligned(nm))
        else:
            X[nm] = I3
        B[nm] = m_mul(X[nm], TB[nm])
    # ---- покой скелета: оси шаблона, длины костей — модели
    Pr = {}
    for nm in order:
        pn = par_name[nm]
        if pn is None:
            Pr[nm] = Pb[nm]
        else:
            local = m_vec(m_T(B[pn]), v_sub(Pb[nm], Pb[pn]))
            Pr[nm] = v_add(Pr[pn], m_vec(TB[pn], local))
    out_nodes = json.loads(json.dumps(nodes))
    for nm in order:
        i = idx[nm]
        pg = (TB[par_name[nm]], Pr[par_name[nm]]) if par_name[nm] else G[parent[i]]
        loc = x_mul(x_inv(pg), (TB[nm], Pr[nm]))
        out_nodes[i].pop('rotation', None); out_nodes[i].pop('translation', None); out_nodes[i].pop('scale', None)
        out_nodes[i]['matrix'] = x_to_gltf(loc)
    out_nodes[mesh_node]['matrix'] = x_to_gltf(x_inv(G[parent[mesh_node]]) if mesh_node in parent else XI)
    ibm = [None] * len(joints)
    for nm in order:
        ibm[jslot[idx[nm]]] = x_to_gltf(x_inv((B[nm], Pb[nm])))

    # ---- веса
    band = R['band']
    arm_band = R.get('arm_band', band)
    spts = sp[:7]
    class Helper:
        """расстояния от точки до костей своей стороны — чтобы делить сетку по ближайшей кости, а не плоскостями"""
        def _d(self, p, S, keys):
            pts = [S[k] for k in keys]
            return min(seg_closest(p, pts[i], pts[i + 1])[0] for i in range(len(pts) - 1))
        def arm(self, x, y, z):
            return self._d((x, y, z), R['L'] if x > 0 else R['R'], ('arm', 'elbow', 'wrist', 'tip'))
        def leg(self, x, y, z):
            return self._d((x, y, z), R['L'] if x > 0 else R['R'], ('hip', 'knee', 'ankle', 'toe', 'toe_end'))
        def torso(self, x, y, z):
            return min(seg_closest((x, y, z), spts[i], spts[i + 1])[0] for i in range(4))
    H = Helper()
    mix = R.get('mix')
    chains = {
        'armL': ([R['L'][k] for k in ('sh', 'arm', 'elbow', 'wrist', 'tip')], ['Left' + b for b in ARM], 'Spine2'),
        'armR': ([R['R'][k] for k in ('sh', 'arm', 'elbow', 'wrist', 'tip')], ['Right' + b for b in ARM], 'Spine2'),
        'legL': ([R['L'][k] for k in ('hip', 'knee', 'ankle', 'toe', 'toe_end')], ['Left' + b for b in LEG], 'Hips'),
        'legR': ([R['R'][k] for k in ('hip', 'knee', 'ankle', 'toe', 'toe_end')], ['Right' + b for b in LEG], 'Hips'),
    }
    torso = (spts[:5], SPINE[:4], None)                     # Hips…Spine2 (до шеи)
    jbytes = bytearray(n * 8)
    wbytes = bytearray(n * 16)
    cache = {}
    stats = {}
    for k in range(n):
        key = (P[k * 3], P[k * 3 + 1], P[k * 3 + 2])
        w = cache.get(key)
        if w is None:
            p = to_units(k)
            w = R['fixed'](*p, H)
            if w is None:
                part = R['part'](*p, H)
                def body():
                    hw = R['head'](*p, H)
                    tw, _ = chain_weights(p, torso[0], torso[1], None, band * 2.0)
                    if hw >= 0.999:
                        return {'Head': 1.0}, 'head'
                    if hw <= 0.001:
                        return tw, 'torso'
                    return {'Head': hw, 'Spine2': 1.0 - hw}, ('head' if hw > 0.5 else 'torso')
                if part is None:
                    w, part = body()
                else:
                    pts, bones, prev = chains[part]
                    w, _ = chain_weights(p, pts, bones, prev, arm_band if part.startswith('arm') else band)
                    mk = mix(*p, H, part) if mix else 1.0
                    if mk < 0.999:                          # ткань: часть веса остаётся на туловище
                        bw, _ = body()
                        w = {nm: v * mk for nm, v in w.items()}
                        for nm, v in bw.items():
                            w[nm] = w.get(nm, 0.0) + v * (1.0 - mk)
                stats[part] = stats.get(part, 0) + 1
            else:
                stats['fixed'] = stats.get('fixed', 0) + 1
            items = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            tot = sum(v for _, v in items)
            w = [(jslot[idx[nm]], v / tot) for nm, v in items if v > 0.0]
            cache[key] = w
        for s in range(4):
            if s < len(w):
                struct.pack_into('<H', jbytes, k * 8 + s * 2, w[s][0])
                struct.pack_into('<f', wbytes, k * 16 + s * 4, w[s][1])
    print('RIG %s: вершин %d (разных мест %d), по частям: %s' % (rid, n, len(cache), ', '.join('%s %d' % kv for kv in sorted(stats.items()))))

    # ---- сросшиеся части: вырезать треугольники между далёкими костями
    slot_name = {jslot[idx[nm]]: nm for nm in order}
    def path_up(nm):
        out_ = [nm]
        while par_name[out_[-1]] is not None:
            out_.append(par_name[out_[-1]])
        return out_
    hop_cache = {}
    def hops(a, b):
        if a == b:
            return 0
        key = (a, b) if a < b else (b, a)
        if key not in hop_cache:
            pa, pb = path_up(slot_name[a]), path_up(slot_name[b])
            sb = {nm: i for i, nm in enumerate(pb)}
            hop_cache[key] = next(i + sb[nm] for i, nm in enumerate(pa) if nm in sb)
        return hop_cache[key]
    dom = [struct.unpack_from('<H', jbytes, k * 8)[0] for k in range(n)]
    ifmt = {5121: 'B', 5123: 'H', 5125: 'I'}[idx_a['componentType']]
    tri = struct.unpack('<%d%s' % (idx_a['count'], ifmt), idx_b)
    keep = []
    cut = 0
    for t in range(0, len(tri), 3):
        a, b, c = dom[tri[t]], dom[tri[t + 1]], dom[tri[t + 2]]
        if max(hops(a, b), hops(b, c), hops(a, c)) > 2:
            cut += 1
        else:
            keep.extend(tri[t:t + 3])
    idx_b = struct.pack('<%d%s' % (len(keep), ifmt), *keep)
    idx_a = dict(idx_a, count=len(keep))
    print('RIG %s: вырезано сросшихся треугольников %d из %d' % (rid, cut, len(tri) // 3))

    # ---- сетка в мире шаблона
    scale = 1.0
    wp = bytearray(n * 12)
    wn = bytearray(n * 12)
    mn = [1e9] * 3; mx = [-1e9] * 3
    for k in range(n):
        q = m_vec(Rw, to_units(k))
        q = (q[0] * scale, q[1] * scale, q[2] * scale)
        struct.pack_into('<3f', wp, k * 12, *q)
        struct.pack_into('<3f', wn, k * 12, *m_vec(Rw, (N[k * 3], N[k * 3 + 1], N[k * 3 + 2])))
        for a in range(3):
            mn[a] = min(mn[a], q[a]); mx[a] = max(mx[a], q[a])

    # ---- запись
    out = bytearray()
    views = []
    def view(data, target=None):
        while len(out) % 4:
            out.append(0)
        v = {'buffer': 0, 'byteOffset': len(out), 'byteLength': len(data)}
        if target:
            v['target'] = target
        out.extend(data)
        views.append(v)
        return len(views) - 1
    acc = []
    def accessor(v, ctype, count, typ, **kw):
        a = {'bufferView': v, 'componentType': ctype, 'count': count, 'type': typ}
        a.update(kw)
        acc.append(a)
        return len(acc) - 1
    a_pos = accessor(view(wp, 34962), 5126, n, 'VEC3', min=mn, max=mx)
    a_nrm = accessor(view(wn, 34962), 5126, n, 'VEC3')
    a_uv = accessor(view(uv_b, 34962), uv_a['componentType'], n, 'VEC2')
    a_idx = accessor(view(idx_b, 34963), idx_a['componentType'], idx_a['count'], 'SCALAR')
    a_j = accessor(view(jbytes, 34962), 5123, n, 'VEC4')
    a_w = accessor(view(wbytes, 34962), 5126, n, 'VEC4')
    a_ibm = accessor(view(struct.pack('<%df' % (16 * len(ibm)), *[x for m in ibm for x in m])), 5126, len(ibm), 'MAT4')
    images = []
    for im in mj.get('images', []):
        bv = mj['bufferViews'][im['bufferView']]
        data = mb[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
        images.append({'name': im.get('name', 'tex'), 'mimeType': im['mimeType'], 'bufferView': view(data)})
    while len(out) % 4:
        out.append(0)
    doc = {
        'asset': {'version': '2.0', 'generator': 'GOD OF GRIMERKA rig-horror.py (сетка Tripo, скелет от %s.glb)' % R['template']},
        'scene': 0, 'scenes': tj['scenes'], 'nodes': out_nodes,
        'meshes': [{'name': 'fn_horror_' + rid, 'primitives': [{'mode': 4, 'material': 0, 'indices': a_idx,
                    'attributes': {'POSITION': a_pos, 'NORMAL': a_nrm, 'TEXCOORD_0': a_uv, 'JOINTS_0': a_j, 'WEIGHTS_0': a_w}}]}],
        'skins': [{'name': 'skin', 'joints': joints, 'inverseBindMatrices': a_ibm}],
        'materials': mj['materials'], 'textures': mj.get('textures', []), 'images': images, 'samplers': mj.get('samplers', []),
        'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(out)}],
    }
    for k in ('extensionsUsed', 'extensionsRequired'):
        if k in mj:
            doc[k] = mj[k]
    out_nodes[mesh_node]['mesh'] = 0
    out_nodes[mesh_node]['skin'] = 0
    jb = json.dumps(doc, ensure_ascii=False).encode('utf-8')
    jb += b' ' * ((4 - len(jb) % 4) % 4)
    with open(dst, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(jb) + 8 + len(out)))
        f.write(struct.pack('<I4s', len(jb), b'JSON')); f.write(jb)
        f.write(struct.pack('<I4s', len(out), b'BIN\x00')); f.write(out)
    print('RIG %s: записан %s, %d КБ' % (rid, os.path.basename(dst), (20 + len(jb) + 8 + len(out)) // 1024))

if __name__ == '__main__':
    main()
