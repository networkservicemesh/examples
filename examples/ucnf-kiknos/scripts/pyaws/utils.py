import subprocess

from shell import run_in


def push(mp, key, val):
    mp[key] = val
    return mp


def reduce_subnets(subnets):
    return reduce(lambda cum, sub: push(cum, sub['AvailabilityZone'], {'id': sub['SubnetId']}),
                  subnets, {})


def get_current_region():
    return subprocess.check_output(["aws", "configure", "get", "default.region"]).decode().rstrip()

