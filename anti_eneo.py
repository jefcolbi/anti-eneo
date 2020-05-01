import subprocess
import json
from pathlib import Path
import re


class AntiEneoBase:
    
    rgx_commit_hash = re.compile(b'\[.*commit.*\b*([0-9a-f]{5,40}).*\]')
    
    def __init__(self, *args, **kwargs):
        pass
    
    def commit(self):
        """Commit the current work"""
        output = subprocess.check_output(['git', 'commit', '-am', '"Anti eneo auto-save"'])
        res = self.rgx_commit_hash.search(output)
        print(output)
        if res:
            return res.group(1)
        
    
    def push(self):
        pass
    
    def watch(self):
        pass
    
    def poll(self):
        pass
    
    def load_config(self):
        """Search and load the config"""
        self.cur_dir = Path.cwd()
        while True:
            try:
                p = self.cur_dir.joinpath('anti_eneo.json')
                with p.open() as fp:
                    self.config = json.load(fp)
            except Exception as e:
                raise ValueError("Unable to find the config file")
                    
    
    def activate_nopass(self):
        pass
    
if __name__ == "__main__":
    anti = AntiEneoBase()
    print(anti.commit())
