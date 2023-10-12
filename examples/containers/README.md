# Container example for the microservice

If there is only one container, there is no need to specify the `memory` an `cpu`, it will by default take all the available resources.
If you want more than one container, then specify for each how much you want to allocate to each container. The overall sum cannot surpass the instance specs.
If you want more than one container, specify the `base`, the one where the traffic from the load balancer will be redirected to. The other ones won't be accessible.

Design possibilities:
- saingle container
- base proxy with nginx to balance to other internal containers
- base backend that will call other internal containers