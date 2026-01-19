import math

def saturate(value, min_value, max_value):
    """
    Saturate a value between min_value and max_value.
    
    Args:
        value: The value to saturate
        min_value: Minimum allowable value
        max_value: Maximum allowable value
    Returns:
        Saturated value
    """
    return max(min(value, max_value), min_value)

def quat2rotm(q):
    """
    Convert a quaternion to a 3x3 rotation matrix.
    
    Args:
        q: quaternion as [x, y, z, w]
    
    Returns:
        3x3 rotation matrix as a list of lists
    """
    x, y, z, w = q
    
    # Normalize quaternion
    norm = math.sqrt(x*x + y*y + z*z + w*w)
    x, y, z, w = x/norm, y/norm, z/norm, w/norm
    
    # Compute rotation matrix elements
    xx, yy, zz = x*x, y*y, z*z
    xy, xz, yz = x*y, x*z, y*z
    wx, wy, wz = w*x, w*y, w*z
    
    return [
        [1 - 2*(yy + zz), 2*(xy - wz), 2*(xz + wy)],
        [2*(xy + wz), 1 - 2*(xx + zz), 2*(yz - wx)],
        [2*(xz - wy), 2*(yz + wx), 1 - 2*(xx + yy)]
    ]

def rotm2eul(R):
    """
    Convert a rotation matrix to Euler angles (roll, pitch, yaw).
    
    Args:
        R: 3x3 rotation matrix as a list of lists
    
    Returns:
        Euler angles as (roll, pitch, yaw) in radians
    """
    sy = math.sqrt(R[0][0] * R[0][0] + R[1][0] * R[1][0])
    
    singular = sy < 1e-6

    if not singular:
        roll = math.atan2(R[2][1], R[2][2])
        pitch = math.atan2(-R[2][0], sy)
        yaw = math.atan2(R[1][0], R[0][0])
    else:
        roll = math.atan2(-R[1][2], R[1][1])
        pitch = math.atan2(-R[2][0], sy)
        yaw = 0

    return roll, pitch, yaw