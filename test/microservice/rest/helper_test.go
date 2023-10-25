package rest_test

import (
	"github.com/aws/aws-sdk-go/aws"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
)

const (
	projectName = "ms" // microservice
	serviceName = "rest"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch: "trunk", // TODO: make it flexible for testing other branches
		Docker: testAwsModule.Docker{
			Repository: testAwsModule.Repository{
				Name: "ubuntu",
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(5),
		Endpoints: []testAwsModule.EndpointTest{
			{
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)
