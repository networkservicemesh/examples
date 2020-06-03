import argparse
import json
import time

from shell import run_out
from eks import AwsCluster
from utils import get_current_region, reduce_subnets, create_elastic_allocation, tag_resource, associate_interface


def create_ec2(key_name, image_id, instance_type, sec_group, network_interfaces, data):
    data = run_out("aws", "ec2", "run-instances",
                   "--key-name", key_name,
                   "--user-data", data,
                   "--image-id", image_id,
                   "--instance-type", instance_type,
                   "--security-group-ids", sec_group,
                   "--network-interfaces", network_interfaces)["Instances"][0]
    instance_id = data["InstanceId"]
    for i in range(0, 10):
        try:
            status = run_out("aws", "ec2", "describe-instance-status",
                             "--instance-id", instance_id)["InstanceStatuses"][0]["InstanceState"]["Name"]
            if status == "running":
                break
        except IndexError:
            pass
        time.sleep(10)
    return data


def define_network_interface(sec_group, subnet_id, index):
    return {
        "DeleteOnTermination": True,
        "Description": "Should be delete, asa test",
        "DeviceIndex": index,
        "Groups": [sec_group],
        "PrivateIpAddresses": [
            {
                "Primary": True,
            }
        ],
        "SubnetId": subnet_id,
    }


def create_subnet(vpc_id, cidr, availability_zone):
    subnets = run_out("aws", "ec2", "describe-subnets",
                      "--filters", "Name=cidr-block,Values={0}".format(cidr))["Subnets"]
    if not subnets:
        return run_out("aws", "ec2", "create-subnet", "--cidr-block", cidr,
                       "--vpc-id", vpc_id, "--availability-zone", availability_zone)["Subnet"]["SubnetId"]
    return subnets[0]["SubnetId"]


def get_primary_interface_id(instance):
    return [interface["NetworkInterfaceId"] for interface in instance["NetworkInterfaces"]
            if interface["Attachment"]["DeviceIndex"] == 0][0]


def main():
    parser = argparse.ArgumentParser(description='Utility for dealing with AWS EC2 instances')
    parser.add_argument('--name', required=True,
                        help='EC2 instance name')
    parser.add_argument('--key-pair', required=True,
                        help="AWS Key Pair for connecting over SSH.")
    parser.add_argument('--image-id', required=True,
                        help="AMI Image ID used for deployment")
    parser.add_argument('--ref', required=True,
                        help='Reference to another AWS deployment, so the instance can be linked in the VPC')
    parser.add_argument('--instance-type', required=False, default="c4.large",
                        help="EC2 instance type")
    parser.add_argument('--user-data', required=False, default="",
                        help="Initial EC2 instance user data")
    parser.add_argument('--interface-count', required=False, type=int, default=1,
                        help="Number of interfaces to be added to instance")
    parser.add_argument('--interface-in-subnet', required=False,
                        help='Creates an interface in a new subnet')
    parser.add_argument('--test', required=False,
                        help='Dump generated config', action='store_true')
    parser.add_argument('--region', required=False,
                        help='Member cluster region')

    args = parser.parse_args()

    region = args.region if args.region else get_current_region()

    reference_cluster = AwsCluster(args.ref, region)
    vpc_id = reference_cluster.get_vpcid()
    sec_group = reference_cluster.get_security_group_id()
    priv_subnets = reduce_subnets(reference_cluster.get_subnets("Private"))
    pub_subnets = reduce_subnets(reference_cluster.get_subnets("Public"))

    # Defining instance interfaces
    cfg = list()
    cfg.append(define_network_interface(sec_group, pub_subnets.values()[0]["id"], 0))
    for i in range(1, args.interface_count):
        cfg.append(define_network_interface(sec_group, priv_subnets.values()[0]["id"], i))
    if args.interface_in_subnet:
        subnet_id = create_subnet(vpc_id, args.interface_in_subnet, pub_subnets.keys()[0])
        tag_resource(subnet_id, "Name", args.name)
        cfg.append(define_network_interface(sec_group, subnet_id, args.interface_count))

    # Creating the EC2 instance
    instance = create_ec2(args.key_pair, args.image_id, args.instance_type, sec_group, json.dumps(cfg), args.user_data)
    instance_id = instance["InstanceId"]
    tag_resource(instance_id, "Name", args.name)

    # Allocating a public IP to the EC2 instance
    allocation_id = create_elastic_allocation(vpc_id)
    tag_resource(allocation_id, "Name", args.name)
    interface_id = get_primary_interface_id(instance)
    associate_interface(interface_id, allocation_id)


if __name__ == '__main__':
    main()
