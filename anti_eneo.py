import subprocess
import json
from pathlib import Path
import re
import getpass


class AntiEneoBase:
    
    rgx_commit_hash = re.compile(b'\[.* ([0-9a-f]+)\]')
    
    def __init__(self, *args, **kwargs):
        self.load_config()
        self.remote_url = self.get_remote_url()
        print(self.remote_url)
        self.create_branch()
        self.activate_nopass()
    
    def commit(self):
        """Commit the current work"""
        output = subprocess.check_output(['git', 'commit', '-am', '"Anti eneo auto-save"'])
        res = self.rgx_commit_hash.search(output)
        if res:
            return res.group(1).decode()        
    
    def push(self):
        output = subprocess.check_output(['git', 'push', self.remote, self.branch])
        print(output)
    
    def watch(self):
        pass
    
    def poll(self):
        
        res = self.commit()
        if res:
            self.push()
    
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
        if not output:
            try:
                output = subprocess.check_output(['git', 'config', 'credential.helper',
                        "cache --timeout={}".format(self.password_timeout)])
            except:
                pass
            
            username = input("Username: ")
            password = getpass.getpass("Password: ")
            
            url = self.remote_url.replace("://", f"://{username}:{password}@")
            
            p = subprocess.Popen(['git', 'push', url], 
                        stdout=subprocess.PIPE, stdin=subprocess.PIPE)
            #line = p.stdout.readline()
            #print(line)
            #username = input(line.decode())
            #p.stdout.write(username)
            #line = p.stdout.readline()
            #print(line)
            #password = input(line.decode())
            #p.stdout.write(password)
            output = p.communicate()[0]
            print(output)
            
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
    
if __name__ == "__main__":
    anti = AntiEneoBase()
    print(anti.poll())
