import subprocess
import json
from pathlib import Path
import re
import getpass
import urllib
import time


class AntiEneoBase:
    
    rgx_commit_hash = re.compile(b'\[.* ([0-9a-f]+)\]')
    rgx_git_provider = re.compile("//(.*)\.[a-zA-Z]{2,3}/")
    
    def __init__(self, *args, **kwargs):
        self.load_config()
        self.remote_url = self.get_remote_url()
        print(self.remote_url)
        self.create_branch()
        self.activate_nopass()
    
    def commit(self):
        """Commit the current work"""
        try:
            output = subprocess.check_output(['git', 'commit', '-am', '"Anti eneo auto-save"'])
        except subprocess.CalledProcessError:
            output = ''
        res = self.rgx_commit_hash.search(output)
        if res:
            return res.group(1).decode()        
    
    def push(self):
        output = subprocess.check_output(['git', 'push', self.remote, self.branch])
        print(output)
    
    def watch(self):
        pass
    
    def poll(self):
        spent = 0
        while spent < self.password_timeout:
            time.sleep(self.push_interval)
            res = self.commit()
            if res:
                self.push()
            spent += self.push_interval
    
    def load_config(self):
        """Search and load the config"""
        self.cur_dir = Path.cwd()
        while True:
            try:
                p = self.cur_dir.joinpath('anti_eneo.json')
                with p.open() as fp:
                    self.config = json.load(fp)
                    self.remote = self.config['remote']
                    self.branch = self.config['branch']
                    self.password_timeout = self.config['password_timeout']
                    self.push_interval = self.config['push_interval']
                break
            except Exception as e:
                raise ValueError("Unable to find the config file")
                    
    
    def activate_nopass(self):
        """Ask for username and password and store them in git credentials cache"""
        print("getting credentials")
        try:
            output = subprocess.check_output(['git', 'config', '--get', 'credential.helper'])
        except subprocess.CalledProcessError:
            output = ''
        except Exception as e:
            raise e
        print("current credentials", output)
        res = self.rgx_git_provider.search(self.remote_url)
        if res:
            provider = res.group(1)
            handler = getattr(self, 'handler_nopass_{}'.format(provider), None)
            if handler is None:
                raise NotImplementedError("No handler implemented for {} provider".format(provider))
            
            handler()
        else:
            raise ValueError("Unable to find the git provider")
            
    def create_branch(self):
        """Create the saving branch if doesn't exist"""
        output = subprocess.check_output(['git', 'branch'])
        print(output)
        res = re.search(self.branch.encode(), output)
        if not res:
            output = subprocess.check_output(['git', 'branch', self.branch])
            print(output)
            
    def get_remote_url(self):
        output = subprocess.check_output(['git', 'remote', '-v'])
        res = re.search(b"%s\s+(.*) +" % self.remote.encode(), output)
        if res:
            return res.group(1).decode()
        
    def handler_nopass_github(self):
        try:
            output = subprocess.check_output(['git', 'config', 'credential.helper',
                    "cache --timeout={}".format(self.password_timeout)])
        except:
            pass
        
        username = input("Username: ")
        username = urllib.parse.quote(username)
        password = getpass.getpass("Password: ")
        password = urllib.parse.quote(password)
        
        url = self.remote_url.replace("://", f"://{username}:{password}@")
        
        p = subprocess.Popen(['git', 'push', url], 
                    stdout=subprocess.PIPE, stdin=subprocess.PIPE)
        
        output = p.communicate()[0]
        return output 
    
if __name__ == "__main__":
    anti = AntiEneoBase()
    print(anti.poll())
