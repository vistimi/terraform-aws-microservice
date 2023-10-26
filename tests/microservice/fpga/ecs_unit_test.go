package microservice_test

import (
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
	serviceName = "fpga"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch: "trunk", // TODO: make it flexible for testing other branches
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Name: util.Ptr("pytorch"),
			},
			Repository: testAwsModule.Repository{
				Name: "torchserve",
			},
		},
	}

	traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:            util.Ptr(8080),
				HealthCheckPath: util.Ptr("/ping"),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8081),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:            util.Ptr(8081),
				HealthCheckPath: util.Ptr("/models"),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8082),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:            util.Ptr(8082),
				HealthCheckPath: util.Ptr("/metrics"),
			}),
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Command:        util.Ptr("curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -v -X POST <URL>/predictions/densenet161 -T kitten.jpg"),
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_FPGA_ECS_EC2_Densenet(t *testing.T) {
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

						"containers": []map[string]any{
							{
								"name":     "unique",
								"docker":   dockerMap,
								"traffics": trafficsMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								"command": []string{
									// it needs the libraries and drivers for neuron to use the inferentia chips
									// https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/arch/neuron-features/neuroncore-pipeline.html
									// https://awsdocs-neuron.readthedocs-hosted.com/en/latest/src/examples/pytorch/pipeline_tutorial/neuroncore_pipeline_pytorch.html
									`apt update; apt install git wget curl -qy; git clone https://github.com/pytorch/serve.git; cd serve; ls examples/image_classifier/densenet_161/; wget https://download.pytorch.org/models/densenet161-8d451a50.pth; torch-model-archiver --model-name densenet161 --version 1.0 --model-file examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files examples/image_classifier/index_to_name.json; mkdir -p model_store; mv densenet161.mar model_store/; echo -e 'load_models=ALL\ninference_address=http://0.0.0.0:8080\nmanagement_address=http://0.0.0.0:8081\nmetrics_address=http://0.0.0.0:8082\nmodel_store=model_store' >> config.properties; torchserve --start --ncs --ts-config config.properties; sleep infinity`,
								},
								"readonly_root_filesystem": false,
								"user":                     "root",
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       "local",
						"instance_types": []string{"inf1.xlarge"},
						"os":             "linux",
						"os_version":     "2",

						"capacities": []map[string]any{
							{
								"type": "ON_DEMAND",
							},
						},
					},
				},
				"ecs": map[string]any{},
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
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics, name, "")
	})
}

//those values where found inside the container for inference made by aws, vmargs are not required

// MXNet
// vmargs=-XX:+UseContainerSupport -XX:InitialRAMPercentage=8.0 -XX:MaxRAMPercentage=10.0 -XX:-UseLargePages -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError

// Torchserve: in config.properties, then do torchserve --ts-config config.properties
// vmargs=-Xmx128m -XX:-UseLargePages -XX:+UseG1GC -XX:MaxMetaspaceSize=32M -XX:MaxDirectMemorySize=10m -XX:+ExitOnOutOfMemoryError