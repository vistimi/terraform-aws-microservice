package microservice_test

import (
	"github.com/aws/aws-sdk-go/aws"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"
)

const (
	projectName = "ms" // microservice
	serviceName = "rest"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/",
		Docker: testAwsModule.Docker{
			Repository: testAwsModule.Repository{
				Name: "ubuntu",
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(80),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(81),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(80),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(443),
				Protocol: util.Ptr("https"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			}),
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(5),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Path:           microserviceInformation.HealthCheckPath,
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)
