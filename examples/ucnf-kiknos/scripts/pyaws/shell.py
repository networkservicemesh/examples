import json
import subprocess


def run_in(*cmd, **data):
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    print(" ".join(cmd))
    json.dump(data, p.stdin)
    p.communicate()
    if p.returncode > 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)


def run_out(*args, **kwargs):
    cmd = [item for item in args]
    for key in kwargs:
        cmd.append("--{0}".format(key))
        cmd.append(kwargs[key])
    print(" ".join(cmd))
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    data = json.load(p.stdout)
    p.communicate()
    if p.returncode > 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)
    return data


def run(*args, **kwargs):
    cmd = [item for item in args]
    for key in kwargs:
        cmd.append("--{0}".format(key))
        cmd.append(kwargs[key])
    print(" ".join(cmd))
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    p.communicate()
    if p.returncode > 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)



