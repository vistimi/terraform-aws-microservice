# ECS

Instances can be Fargate or EC2

```mermaid
flowchart LR
    Inbound_traffic -- HTTP(S)/TCP --> ELB -- scaling --> Target_Group -- provision --> ECS_service
    ELB -- traffic --> ECS_service
```

```mermaid
flowchart LR
    ECS_service_1 --> task_1
    task_1 --> ASG_on_demand & ASG_spot
    ASG_on_demand --> instance_on_demand_1 & instance_on_demand_2
    ASG_spot --> instance_spot_1 & instance_spot_2

    ECS_service_1 --> task_2...
```

# network mode

- awsvpc
  - for fargate
- bridge   
  - for EC2 with many instances, it allows dynamic mapping
- host
  - for EC2 with a single instance, cannot have dynamic port mapping, hence it is not made for many instances because a port can be taken by only one instance. But it is more performant than bridge network.