import roslibpy
import surfer_lib.utils as utils

class Detection:
    def __init__(self, x=0.0, y=0.0, w=0.0, h=0.0):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.pos = (0,0,0)
        self.confidence = 0.0
        self.class_id = "unknown"

class Surfer:
    def __init__(self, host='localhost', port=9090, name='surfer'):
        """
        Initialize Surfer with rosbridge connection parameters.
        
        Args:
            host (str): The rosbridge server host address
            port (int): The rosbridge server port
            name (str): The name identifier for the Surfer instance
        """
        self.host = host
        self.port = port
        self.name = name
        self.client = None

        self.accel = [0.0, 0.0, 0.0]
        self.gyro = [0.0, 0.0, 0.0]
        self.quat = [0.0, 0.0, 0.0, 0.0]
        self.eul = [0.0, 0.0, 0.0]

        self.detections = []

        self.mode = 'IDLE'  # Default mode
        self.group = None
        self.armed = False
        self.behavior = None
        self.id = None

    def initialize_comms(self):
        """Initialize communication topics and subscribers."""

        self.imu_sub = roslibpy.Topic(self.client, '/'+self.name+'/imu', 'sensor_msgs/Imu')
        self.imu_sub.subscribe(self.imu_callback)   

        self.status_sub = roslibpy.Topic(self.client, '/'+self.name+'/status', 'surfer_msgs/Status')
        self.status_sub.subscribe(self.status_callback)     

        self.detect_sub = roslibpy.Topic(self.client, '/'+self.name+'/detections', 'vision_msgs/Detection2DArray')
        self.detect_sub.subscribe(self.detection_callback)

        self.cmd_vel_pub = roslibpy.Topic(self.client, '/'+self.name+'/set_cmd_vel', 'geometry_msgs/Twist')
        self.cmd_vel_pub.advertise()

        self.cmd_frc_pub = roslibpy.Topic(self.client, '/'+self.name+'/set_cmd_force', 'geometry_msgs/Twist')
        self.cmd_frc_pub.advertise()

        self.cmd_mot_pub = roslibpy.Topic(self.client, '/'+self.name+'/set_cmd_motor', 'std_msgs/Float32MultiArray')
        self.cmd_mot_pub.advertise()

        self.srv_reset_imu = roslibpy.Service(self.client, '/'+self.name+'/reset_imu', 'std_srvs/Trigger')

    def imu_callback(self, msg):
        """Callback function to handle incoming IMU messages."""
        self.accel[0] = msg['linear_acceleration']['x']
        self.accel[1] = msg['linear_acceleration']['y']
        self.accel[2] = msg['linear_acceleration']['z']
        self.gyro[0] = msg['angular_velocity']['x']
        self.gyro[1] = msg['angular_velocity']['y']
        self.gyro[2] = msg['angular_velocity']['z']
        self.eul[0] = msg['orientation']['x']
        self.eul[1] = msg['orientation']['y']
        self.eul[2] = msg['orientation']['z']

    def status_callback(self, msg):
        print(msg)
        self.mode = msg['mode']
        self.group = msg['group']
        self.armed = msg['armed']
        self.behavior = msg['behavior']
        self.id = msg['id']

    def detection_callback(self, msg):
        # Process detection data as needed
        for detection in msg['detections']:
            # print(detection)
            
            bbox = detection['bbox']
            # print(bbox)
            detection_obj = Detection(
                x=bbox['center']['position']['x'],
                y=bbox['center']['position']['y'],
                w=bbox['size_x'],
                h=bbox['size_y']
            )
            detection_obj.pos = detection['results'][0]['pose']['pose']['position']['x'], detection['results'][0]['pose']['pose']['position']['y'], detection['results'][0]['pose']['pose']['position']['z']
            detection_obj.confidence = detection['results'][0]['hypothesis']['score']
            detection_obj.class_id = detection['results'][0]['hypothesis']['class_id']
            self.detections.append(detection_obj)

    def get_accel(self) -> list:
        """Get the latest accelerometer data."""
        return self.accel
    def get_gyro(self) -> list:
        """Get the latest gyroscope data."""
        return self.gyro
    def get_quat(self) -> list:
        """Get the latest quaternion orientation data."""
        return self.quat
    def get_eul(self) -> list:
        """Get the latest Euler angles (placeholder, not implemented)."""
        return self.eul

    def get_detections(self) -> list:
        curr_detections = self.detections
        self.detections = []
        """Get the latest detection data."""
        return curr_detections
    
    def reset_imu(self) -> bool:
        """Call the reset IMU service."""
        if self.client and self.client.is_connected:
            request = roslibpy.ServiceRequest()
            result = self.srv_reset_imu.call(request)
            return result.success
        else:
            print("Not connected to rosbridge")
            return False

    def set_vel_cmd(self, u: float = 0.0, v: float = 0.0, r: float = 0.0) -> None:
        """Publish velocity command to the cmd_vel topic."""
        """ These values should be in the range -1.0 to 1.0 and are scaled in the surfer driver"""
        """ based on the maximum vel_cmd settings"""
        """ u: forward command, v: lateral velocity (left), r: rotational velocity (rotate left) """
        u = utils.saturate(u, -1.0, 1.0)
        v = utils.saturate(v, -1.0, 1.0)
        r = utils.saturate(r, -1.0, 1.0)
        twist_msg = roslibpy.Message({
            'linear': {
                'x': u,
                'y': v,
                'z': 0.0
            },
            'angular': {
                'x': 0.0,
                'y': 0.0,
                'z': r
            }
        })
        self.cmd_vel_pub.publish(twist_msg)

    def set_force_cmd(self, fx: float = 0.0, fy: float = 0.0, mz: float = 0.0) -> None:
        """Publish force command to the cmd_force topic."""
        """ These values should be in the range -1.0 to 1.0 and are scaled in the surfer driver"""
        """ based on the maximum force_cmd settings"""
        """ fx: forward force, fy: lateral force (left), mz: rotational moment (rotate left) """
        
        fx = utils.saturate(fx, -1.0, 1.0)
        fy = utils.saturate(fy, -1.0, 1.0)
        mz = utils.saturate(mz, -1.0, 1.0)

        twist_msg = roslibpy.Message({
            'linear': {
                'x': fx,
                'y': fy,
                'z': 0.0
            },
            'angular': {
                'x': 0.0,
                'y': 0.0,
                'z': mz
            }
        })
        self.cmd_frc_pub.publish(twist_msg)

    def set_motor_cmd(self, m1: float = 0.0, m2: float = 0.0, m3: float = 0.0, m4: float = 0.0) -> None:
        """Publish motor command to the motor_cmd topic.
        
        Args:
            m1: motor 1 command (-1.0 to 1.0)
            m2: motor 2 command (-1.0 to 1.0)
            m3: motor 3 command (-1.0 to 1.0)
            m4: motor 4 command (-1.0 to 1.0)
        """
        m1 = utils.saturate(m1, -1.0, 1.0)
        m2 = utils.saturate(m2, -1.0, 1.0)
        m3 = utils.saturate(m3, -1.0, 1.0)
        m4 = utils.saturate(m4, -1.0, 1.0)
        motor_msg = roslibpy.Message({
            'data': [m1, m2, m3, m4]
        })
        self.cmd_mot_pub.publish(motor_msg)
            
    def connect(self) -> None:
        """Establish connection to rosbridge server."""
        self.client = roslibpy.Ros(host=self.host, port=self.port)
        self.client.run()
        print(f"Connected to rosbridge at {self.host}:{self.port}")
        if( self.client.is_connected):
            self.initialize_comms()
        
    def disconnect(self) -> None:
        """Close the rosbridge connection."""
        if self.client:
            self.client.terminate()
            print("Disconnected from rosbridge")

    def get_topics(self) -> list:
        """Retrieve the list of available topics from rosbridge."""
        if self.client and self.client.is_connected:
            return self.client.get_topics()
        else:
            print("Not connected to rosbridge")
            return []
    def is_connected(self) -> bool:
        """Check if connected to rosbridge."""
        return self.client and self.client.is_connected
    
    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
