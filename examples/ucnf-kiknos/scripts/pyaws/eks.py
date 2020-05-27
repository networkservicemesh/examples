import re

from shell import run_out


class AwsCluster(object):
    def __init__(self, cluster_name, region):
        self.name = cluster_name
        self.region = region
        self.clusterInfo = self.get_cluster_info()

    def get_security_group_id(self):
        sgs = self.clusterInfo['cluster']['resourcesVpcConfig']['securityGroupIds']

        if len(sgs) < 1:
            raise Exception("cluster doesn't have any security groups, please make sure that you have active security "
                            "groups enabled on your cluster")
        return sgs[0]

    def get_cluster_info(self):
        return run_out("aws", "eks", "describe-cluster", name=self.name, region=self.region, output="json")

    def get_subnets_by_ids(self):
        return run_out("aws", "ec2", "describe-subnets", "--subnet-ids", *self.clusterInfo['cluster']['resourcesVpcConfig']['subnetIds'],
                       region=self.region)

    def get_vpcid(self):
        return self.clusterInfo['cluster']['resourcesVpcConfig']['vpcId']

    def get_subnets(self, name):
        return reduce(lambda cum, sub:
                      reduce(lambda tag_cum, tag:
                             tag_cum + [sub] if tag['Key'] == "Name" and bool(re.search(name, tag['Value']))
                             else tag_cum,
                             sub['Tags'],
                             []) + cum if sub['Tags'] else cum,
                      self.get_subnets_by_ids()['Subnets'],
                      [])
