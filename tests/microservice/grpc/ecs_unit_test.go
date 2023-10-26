package microservice_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"
)

const (
	projectName = "ms" // microservice
	serviceName = "grpc"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch: "trunk", // TODO: make it flexible for testing other branches
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Name: util.Ptr("grpc"),
			},
			Repository: testAwsModule.Repository{
				Name: "java-example-hostname",
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	// gRPC requires HTTPS
	traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(443),
				Protocol: util.Ptr("https"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:            util.Ptr(50051),
				ProtocolVersion: util.Ptr("grpc"),
				StatusCode:      util.Ptr("0,12"),
				HealthCheckPath: util.Ptr("/helloworld.Greeter/SayHello"),
				// HealthCheckPath: util.Ptr("/grpc.health.v1.Health/Check"),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(444),
				Protocol: util.Ptr("https"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:            util.Ptr(50051),
				ProtocolVersion: util.Ptr("grpc"),
				StatusCode:      util.Ptr("0,12"),
				HealthCheckPath: util.Ptr("/helloworld.Greeter/SayHello"),
				// HealthCheckPath: util.Ptr("/grpc.health.v1.Health/Check"),
			}),
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Request: util.Ptr(`{"name": "World"}`),
				// Request:    util.Ptr(`{"service": ""}`),
				MaxRetries: util.Ptr(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Grpc_ECS_EC2(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics)

	serviceNameSuffix := "unique"

	name := strings.ToLower(util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id))

	options := util.Ptr(terraform.Options{
		TerraformDir: microservicePath,
		Vars: map[string]interface{}{
			"name": name,

			"vpc": map[string]any{
				"id":       util.GetEnvVariable("VPC_ID"),
				"tag_tier": "public",
			},

			"orchestrator": map[string]any{
				"group": map[string]any{
					"name": serviceNameSuffix,
					"deployment": map[string]any{
						"min_size":     1,
						"max_size":     1,
						"desired_size": 1,

						"cpu":    2000,
						"memory": 3700,

						"containers": []map[string]any{
							{
								"name":                     "unique",
								"docker":                   dockerMap,
								"traffics":                 trafficsMap,
								"readonly_root_filesystem": false,

								"cpu":    2000,
								"memory": 3700,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"t3.medium"},
						"os":             "linux",
						"os_version":     "2023",

						"capacities": []map[string]any{
							{
								"type": "ON_DEMAND",
							},
						},
					},
				},
				"ecs": map[string]any{},
			},

			"route53": map[string]any{
				"zones": []map[string]any{
					{
						"name": fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX")),
					},
				},
				"record": map[string]any{
					"prefixes":       []string{"www"},
					"subdomain_name": name,
				},
			},

			"tags": tags,
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.Init(t, options)
		terraform.Plan(t, options)
		terraform.Apply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateGrpcEndpoints(t, microservicePath, deployment, traffics, name, "")
	})
}