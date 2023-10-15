# AWS microservice terraform module

Terraform module which creates a microservice that works for all EC2 instances. The applications can range from deploying general purpose applications, machine learning training. machine learning inference, high performance computing and more.

The purpose is to unify under one confguration a general purpose deployment to reduce the technical debt on the infrastructure. It is a simple, safe and scalable way to deploy applications with containers.
it is also a great alternative to Sagemaker, it will be 40% cheaper but will require some work on the infrastructure for deploying it.

The configuration aims to support Kubernetes and have the same modules for other cloud providers.

The microservice has the following specifications:

- Load balancer
    - HTTP(S)
    - Rest/gRPC
- Auto scaling
- DNS with Route53
- Environement file
- Cloudwatch logs
- Container orchestrators
    - [ ] ECS
      - [x] Fargate
      - [ ] EC2
          - [x] General Purpose
          - [x] Compute Optimized
          - [x] Memory Optimized
          - [x] Accelerated Computing (GPU, Inferentia, Trainium)
          - [ ] Accelerated Computing (Gaudi) config not ok/not tested
          - [ ] Storage Optimized: config ok/not tested
          - [ ] HPC Optimized: config ok/not tested
    - [ ] EKS
        - [ ] Fargate
        - [ ] EC2

To see which specific instances are supported, please check [instances](). Feel free to contribute to the project by adding features or isntances

## Architecture

![Architecture](https://github.com/vistimi/terraform-aws-microservice/blob/trunk/images/architecture.png?raw=true)

## Examples

Go check the [examples](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/examples)
Go check the [tests](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/test/microservice)

## ECS vs EKS equivalent

|         ECS          |    EKS     |
| :------------------: | :--------: |
|       cluster        |  cluster   |
|       service        | node-group |
|         task         |    node    |
|   task-definition    | deployment |
| container-definition |    pod     |

## Errors

##### insufficient memory
```
The closest matching container-instance `<id>` has insufficient memory available. For more information, see the Troubleshooting section of the Amazon ECS Developer Guide
```

It means that the memory given to the container or the service or both is superior to what is allowed. ECS requires a certain amount of memory to run and is different for each instance. Currently there is only 90% of the memory used for the containers, leaving enough overhead space to not encounter that problem. To override that from happening you can override the memory and cpu allocation by specifying it in the containers.

##### insufficient instances
```
Scaling activity `<id>`: Failed: We currently do not have sufficient `<instance_type>` capacity in the Availability Zone you requested (us-east-1c). Our system will be working on provisioning additional capacity. You can currently get `<instance_type>` capacity by not specifying an Availability Zone in your request or choosing us-east-1a, us-east-1b, us-east-1d, us-east-1f. Launching EC2 instance failed
```

It means that not available instances in the available zones. Unfortunately AWS does not have enough capacity in some regions. A possible solution would be to retry deploying the microservice until it is successful.

## License

See [LICENSE](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/LICENSE) for full details.