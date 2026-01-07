import cv2
from datetime import datetime
import os
import argparse

def main():
    """Video stream viewer - capture and record streams from HTTP/RTSP sources."""
    parser = argparse.ArgumentParser(description='Video stream viewer with recording capability')
    parser.add_argument('--ip', type=str, default='127.0.0.1',
                        help='IP address of the stream source (default: 127.0.0.1)')
    parser.add_argument('--topic', type=str, default='/grace/rgb/image_raw',
                        help='ROS topic name (default: /grace/rgb/image_raw)')
    parser.add_argument('--port', type=int, default=9091,
                        help='Port number (default: 9091)')
    args = parser.parse_args()
    
    # script_dir = os.path.dirname(os.path.abspath(__file__))
    user = os.getenv('USER')
    save_path = f"/home/{user}/ew309_workspace/videos"
    
    # Construct stream URL from arguments
    stream_url = f'http://{args.ip}:{args.port}/stream?topic={args.topic}'
    print(f"Connecting to: {stream_url}")
    
    # cap = cv2.VideoCapture('rtsp://192.168.2.1:8554/back')
    cap = cv2.VideoCapture(stream_url)

    # Get video properties for the writer
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    if fps == 0:  # fallback if fps not available
        fps = 20

    recording = False
    out = None

    print("Press SPACE to start/stop recording")
    print("Press 'q' to quit")

    while True:
        ret, frame = cap.read()

        if ret:
            # Display recording status on frame
            # if recording:
            #     cv2.putText(frame, "REC", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 
            #                1, (0, 0, 255), 2)
            
            cv2.imshow('RTSP Stream', frame)
            
            # Write frame if recording
            if recording and out is not None:
                out.write(frame)

        key = cv2.waitKey(10) & 0xFF
        
        # Toggle recording with space bar
        if key == ord(' '):
            if not recording:
                # Start recording
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"video_{timestamp}.mp4"
                filename = os.path.join(save_path, filename)
                fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                out = cv2.VideoWriter(filename, fourcc, fps, (frame_width, frame_height))
                recording = True
                print(f"Recording started: {filename}")
            else:
                # Stop recording
                recording = False
                if out is not None:
                    out.release()
                    out = None
                print("Recording stopped")
        
        # Quit with 'q'
        if key == ord('q'):
            break

    # Cleanup
    if out is not None:
        out.release()
    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    main()
