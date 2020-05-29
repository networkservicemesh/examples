import subprocess
import time

from shell import run, run_out


def push(mp, key, val):
    mp[key] = val
    return mp


def reduce_subnets(subnets):
    return reduce(lambda cum, sub: push(cum, sub['AvailabilityZone'], {'id': sub['SubnetId']}),
                  subnets, {})


def get_current_region():
    return subprocess.check_output(["aws", "configure", "get", "default.region"]).decode().rstrip()


def tag_resource(instance, tag_key, tag_value):
    run("aws", "ec2", "create-tags", "--resource", instance, "--tags", "Key={0},Value={1}".format(tag_key, tag_value))


def create_elastic_allocation(vpc_id):
    return run_out("aws", "ec2", "allocate-address", "--domain", vpc_id)["AllocationId"]


def associate_interface(interface_id, allocation_id):
    wait_for_interface_ready(interface_id)
    run_out("aws", "ec2", "associate-address",
            "--allocation-id", allocation_id,
            "--network-interface-id", interface_id)


def wait_for_interface_ready(interface_id):
    for i in range(0, 10):
        time.sleep(10)
        interfaces = run_out("aws", "ec2", "describe-network-interfaces", "--network-interface-ids", interface_id,
                             "--filters", "Name=status,Values=in-use")["NetworkInterfaces"]
        if len(interfaces) > 0:
            print interfaces
            return
