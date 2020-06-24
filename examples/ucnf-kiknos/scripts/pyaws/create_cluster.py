import argparse
import json
import subprocess
import sys

from eks import AwsCluster
from shell import run_out, run_in
from utils import reduce_subnets, get_current_region

DEFAULT_CIDR_BLOCK = "192.168.0.0/16"


def create_cluster(data):
    run_in("eksctl", "create", "cluster", "-f", "-", **data)


def generate_cluster_cfg(name, region, cidr, vpcid, private, public):
    return {
        'apiVersion': 'eksctl.io/v1alpha5',
        'kind': 'ClusterConfig',

        'metadata': {
            'name': name,
            'region': region
        },
        'vpc': {
            'cidr': cidr,
            'id': vpcid,
            'subnets': {
                'private': reduce_subnets(private),
                'public': reduce_subnets(public)
            }
        } if private and public and vpcid else {
            'cidr': cidr,
            'nat': {'gateway': 'Single'},
            'clusterEndpoints': {'publicAccess': True, 'privateAccess': True}
        },

        'nodeGroups': [
            {
                'name': 'member-ng',
                'minSize': 2,
                'maxSize': 2,
                'instancesDistribution': {
                    'maxPrice': 0.093,
                    'instanceTypes': ["t3a.large", "t3.large"],
                    'onDemandBaseCapacity': 0,
                    'onDemandPercentageAboveBaseCapacity': 50,
                    'spotInstancePools': 2
                },
                'ssh': {
                    'publicKeyPath': '~/.ssh/id_rsa.pub'
                },
                'iam': {
                    'withAddonPolicies': {
                        'externalDNS': True
                    }
                }
            }
        ]
    }


def open_security_groups(cluster_name, region):
    res = run_out("aws", "ec2", "describe-security-groups",
                  "--region", region, "--filters",
                  "Name=tag:aws:cloudformation:logical-id,Values=SG",
                  "Name=tag:alpha.eksctl.io/cluster-name,Values=" + cluster_name)

    sg = res['SecurityGroups']
    if len(sg) < 1:
        raise Exception("no security group found for cluster {0} nodegroup".format(cluster_name))

    subprocess.check_call(
        ["aws", "ec2", "authorize-security-group-ingress", "--group-id", sg[0]['GroupId'], "--protocol", "-1",
         "--port", "-1", "--cidr", "0.0.0.0/0", "--region", region])

def main():
    parser = argparse.ArgumentParser(description='Utility for dealing with AWS clusters')
    parser.add_argument('--name', required=True,
                        help='Member cluster name to create config for.')
    parser.add_argument('--region', required=False,
                        help='Member cluster region')
    parser.add_argument('--ref', required=False,
                        help='Reference cluster name (client cluster will use reference clusters vpc when is created)')
    parser.add_argument('--cidr', required=False,
                        help='Client cluster name to create config yaml for.')
    parser.add_argument('--test', required=False,
                        help='Dump generated config', action='store_true')
    parser.add_argument('--open-sg', required=False,
                        help='Open all ports and all ips for SecurityGroups', dest='open_sg', action='store_true')

    args = parser.parse_args()

    cidr = args.cidr if args.cidr else DEFAULT_CIDR_BLOCK
    region = args.region if args.region else get_current_region()

    priv_subnets, pub_subnets, vpcid = None, None, None
    if args.ref:
        reference_cluster = AwsCluster(args.ref, region)
        priv_subnets = reference_cluster.get_subnets("Private")
        pub_subnets = reference_cluster.get_subnets("Public")
        vpcid = reference_cluster.get_vpcid()

    cfg = generate_cluster_cfg(args.name, region, cidr, vpcid, priv_subnets, pub_subnets)
    if args.test:
        json.dump(cfg, sys.stdout, indent=4)
        return

    create_cluster(cfg)
    if args.open_sg:
        open_security_groups(args.name, region)


if __name__ == '__main__':
    main()
