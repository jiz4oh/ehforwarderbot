#!/usr/bin/python3
import subprocess, os, signal, datetime, time, json, sys

version = os.environ.get('COMWECHAT_VERSION', '3.9.12.16')

class DockerWechatHook:
    def __init__(self):
        signal.signal(signal.SIGINT, self.now_exit)
        signal.signal(signal.SIGHUP, self.now_exit)
        signal.signal(signal.SIGTERM, self.now_exit)

    def now_exit(self, signum, frame):
        self.exit_container()

    def prepare(self):
        self.prepare = subprocess.run(['unzip', '-d', 'comwechat', 'comwechat.zip'])
        self.prepare = subprocess.run(['mv', '/WeChatHook.exe', '/comwechat/http/WeChatHook.exe'])

    def run_vnc(self):
        # 根据 VNCPASS 环境变量生成 vncpasswd 文件
        os.makedirs('/root/.vnc', mode=755, exist_ok=True)
        passwd_output = subprocess.run(['/usr/bin/vncpasswd','-f'],input=os.environ['VNCPASS'].encode(),capture_output=True)
        with open('/root/.vnc/passwd', 'wb') as f:
            f.write(passwd_output.stdout)
        os.chmod('/root/.vnc/passwd', 0o700)
        self.vnc = subprocess.Popen(['/usr/bin/vncserver','-localhost',
            'no', '-xstartup', '/usr/bin/openbox' ,':5'])

    def run_wechat(self):
        # if not os.path.exists("/wechat_installed.txt"):
        #     self.wechat = subprocess.run(['wine','WeChatSetup.exe'])
        #     with open("/wechat_installed.txt", "w") as f:
        #         f.write("True\n")
        # self.wechat = subprocess.run(['wine', 'explorer.exe'])
        self.wechat = subprocess.Popen(['wine','/home/user/.wine/drive_c/Program Files/Tencent/WeChat/WeChat.exe'])
        # self.wechat = subprocess.run(['wine','/home/user/.wine/drive_c/Program Files/Tencent/WeChat/WeChat.exe'])

    def run_hook(self):
        print("等待 5 秒再 hook", flush=True)
        time.sleep(5)
        self.reg_hook = subprocess.Popen(['wine','/comwechat/http/WeChatHook.exe'])
        # self.reg_hook = subprocess.run(['wine', 'explorer.exe'])
    
    def change_version(self):
        time.sleep(5)
        result = subprocess.run(['curl', '-X', 'POST', 'http://127.0.0.1:18888/api/?type=35', '-H', 'Content-Type: application/json', '-d', json.dumps({"path": "/comwechat/http/WeChatHook.exe", "version": version})], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(f"Curl command failed with error: {result.stderr.decode()}", flush=True)
            print("版本修改失败", flush=True)
            self.exit_container()
            sys.exit(1)
        else:
            print("版本已经修改", flush=True)

    def exit_container(self):
        print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 正在退出容器...', flush=True)
        try:
            print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 退出微信...', flush=True)
            os.kill(self.wechat.pid, signal.SIGTERM)
        except:
            pass
        try:
            print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 退出Hook程序...', flush=True)
            os.kill(self.reg_hook.pid, signal.SIGTERM)
        except:
            pass
        try:
            print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 退出VNC...', flush=True)
            os.kill(self.vnc.pid, signal.SIGTERM)
        except:
            pass

    def run_all_in_one(self):
        print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 启动容器中...', flush=True)
        self.prepare()
        self.run_vnc()
        self.run_wechat()
        self.run_hook()
        self.change_version()
        while True:
            time.sleep(1)
        print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+ ' 感谢使用.', flush=True)


if __name__ == '__main__' :
    print('---All in one 微信 ComRobot 容器---', flush=True)
    hook = DockerWechatHook()
    hook.run_all_in_one()
