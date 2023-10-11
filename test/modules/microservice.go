package module

import (
	"crypto/tls"
	"fmt"
	"math/rand"
	"regexp"
	"strings"
	"testing"
	"time"

	terratest_http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	terratestLogger "github.com/gruntwork-io/terratest/modules/logger"
	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/vistimi/terraform-aws-microservice/util"
)

type EC2Instance struct {
	Name          string
	Cpu           int
	Gpu           int
	Memory        int
	MemoryAllowed int
	Ram           int
	RamAllowed    int
	DevicePaths   []string
	Architecture  string
	Processor     string
}

type MicroserviceInformation struct {
	Branch          string
	HealthCheckPath string
	Docker          Docker
}
type Docker struct {
	Registry   *Registry
	Repository Repository
	Image      *Image
}
type Registry struct {
	Name *string
	Ecr  *Ecr
}
type Ecr struct {
	Privacy     string
	AccountId   *string
	RegionName  *string
	PublicAlias *string
}
type Repository struct {
	Name string
}
type Image struct {
	Tag string
}

type EndpointTest struct {
	Command             *string // replaced `<URL>` occurences by the real URL
	Request             *string
	Path                string
	ExpectedStatus      int
	ExpectedBody        *string
	MaxRetries          *int
	SleepBetweenRetries *time.Duration
}

type DeploymentTest struct {
	MaxRetries          *int
	SleepBetweenRetries *time.Duration
	Endpoints           []EndpointTest
}

type LogTest struct {
	Group  string
	Stream string
}

type TrafficPoint struct {
	Port            *int
	Protocol        string
	ProtocolVersion *string
	StatusCode      *string
}

type Traffic struct {
	Listener TrafficPoint
	Target   TrafficPoint
	Base     *bool
}

func SetupMicroservice(t *testing.T, microserviceInformation MicroserviceInformation, traffics []Traffic) (id string, tags map[string]string, trafficsMap []map[string]any, docker map[string]any) {
	rand.Seed(time.Now().UnixNano())

	// global variables
	id = util.RandomID(4)
	tags = map[string]string{
		"TestID":  id,
		"Account": util.GetEnvVariable("AWS_ACCOUNT_ID"),
		"Region":  util.GetEnvVariable("AWS_REGION_NAME"),
	}

	for _, traffic := range traffics {
		target := map[string]any{
			"protocol":          traffic.Target.Protocol,
			"health_check_path": microserviceInformation.HealthCheckPath,
		}
		target = util.ObjNil(traffic.Target.Port, target, "port")
		target = util.ObjNil(traffic.Target.ProtocolVersion, target, "protocol_version")
		target = util.ObjNil(traffic.Target.StatusCode, target, "status_code")

		listener := map[string]any{
			"protocol": traffic.Listener.Protocol,
		}
		listener = util.ObjNil(traffic.Listener.Port, listener, "port")
		listener = util.ObjNil(traffic.Listener.ProtocolVersion, listener, "protocol_version")

		trafficsMap = append(trafficsMap, map[string]any{
			"listener": listener,
			"target":   target,
			"base":     util.Value(traffic.Base),
		})
	}

	registry := make(map[string]any)
	if microserviceInformation.Docker.Registry != nil {
		registry = util.ObjNil(microserviceInformation.Docker.Registry.Name, registry, "name")
		if microserviceInformation.Docker.Registry.Ecr != nil {
			registry["ecr"] = map[string]any{
				"privacy": microserviceInformation.Docker.Registry.Ecr.Privacy,
			}
			registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.AccountId, registry["ecr"].(map[string]any), "account_id")
			registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.RegionName, registry["ecr"].(map[string]any), "region_name")
			registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.PublicAlias, registry["ecr"].(map[string]any), "public_alias")
		}
	}

	docker = map[string]any{
		"registry": registry,
		"repository": map[string]any{
			"name": microserviceInformation.Docker.Repository.Name,
		},
	}
	if microserviceInformation.Docker.Image != nil {
		docker["image"] = map[string]any{
			"tag": microserviceInformation.Docker.Image.Tag,
		}
	}

	return id, tags, trafficsMap, docker
}

func ValidateMicroservice(t *testing.T, name string, deployment DeploymentTest, serviceName string) {
	terratestStructure.RunTestStage(t, "validate_microservice", func() {
		serviceCount := int64(1)
		accountRegion := util.GetEnvVariable("AWS_REGION_NAME")
		ValidateEcs(t, accountRegion, name, serviceName, serviceCount, deployment)
	})
}

func ValidateRestEndpoints(t *testing.T, microservicePath string, deployment DeploymentTest, traffics []Traffic, name, modulePath string) {
	terratestLogger.Log(t, "Validate Rest endpoints")
	sleepBetweenRetries := 30 * time.Second
	terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
	time.Sleep(sleepBetweenRetries)

	for _, traffic := range traffics {
		if traffic.Listener.Protocol == "http" {
			port := util.Value(traffic.Listener.Port, 80)
			// test Load Balancer HTTP
			elb := ExtractFromState(t, microservicePath, util.Format(".", modulePath, "ecs.elb"))
			terratestLogger.Log(t, fmt.Sprintf("elb :: %+v", elb))
			if elb != nil {
				elbDnsUrl := elb.(map[string]any)["lb"].(map[string]any)["dns_name"].(string)
				if elbDnsUrl == "" || elbDnsUrl == "null" {
					t.Fatalf("ECS ELB DNS is null: %s", elbDnsUrl)
				}
				elbDnsUrl = fmt.Sprintf("http://%s:%d", elbDnsUrl, port)
				fmt.Printf("\n\nLoad Balancer DNS = %s\n\n", elbDnsUrl)

				// add dns to endpoints
				endpointsLoadBalancer := []EndpointTest{}
				for _, endpoint := range deployment.Endpoints {
					newEndpoint := EndpointTest{
						ExpectedStatus:      endpoint.ExpectedStatus,
						ExpectedBody:        endpoint.ExpectedBody,
						MaxRetries:          endpoint.MaxRetries,
						SleepBetweenRetries: endpoint.SleepBetweenRetries,
					}

					if endpoint.Command != nil {
						re := regexp.MustCompile(`<URL>`)
						newEndpoint.Command = util.Ptr(re.ReplaceAllString(util.Value(endpoint.Command), elbDnsUrl))
					} else {
						newEndpoint.Path = elbDnsUrl + endpoint.Path
					}
					endpointsLoadBalancer = append(endpointsLoadBalancer, newEndpoint)
				}

				terratestStructure.RunTestStage(t, "validate_rest_endpoints_load_balancer", func() {
					TestRestEndpoints(t, endpointsLoadBalancer)
				})
			}

			// test Route53
			route53 := ExtractFromState(t, microservicePath, "ecs.route53")
			terratestLogger.Log(t, fmt.Sprintf("route53 :: %+v", route53))
			if route53 != nil {
				records := route53.(map[string]any)["records"].(map[string]any)
				terratestLogger.Log(t, fmt.Sprintf("records :: %+v", records))
				if len(records) != 0 {
					recordName := records[fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))].(map[string]any)["name"].(map[string]any)[name+" A"].(string)
					route53DnsUrl := fmt.Sprintf("http://%s:%d", recordName, port)
					fmt.Printf("\n\nRoute53 DNS = %s\n\n", route53DnsUrl)

					// add dns to endpoints
					endpointsRoute53 := []EndpointTest{}
					for _, endpoint := range deployment.Endpoints {
						newEndpoint := endpoint

						if endpoint.Command != nil {
							re := regexp.MustCompile(`<URL>`)
							newEndpoint.Command = util.Ptr(re.ReplaceAllString(util.Value(endpoint.Command), route53DnsUrl))
						} else {
							newEndpoint.Path = route53DnsUrl + endpoint.Path
						}
						endpointsRoute53 = append(endpointsRoute53, newEndpoint)
					}

					terratestStructure.RunTestStage(t, "validate_rest_endpoints_route53", func() {
						TestRestEndpoints(t, endpointsRoute53)
					})
				}
			}

		} else if traffic.Listener.Protocol == "https" {
			// port := util.Value(traffic.Listener.Port, 443)
			// TODO: add HTTPS
		}
	}
}

func TestRestEndpoints(t *testing.T, endpoints []EndpointTest) {
	tlsConfig := tls.Config{}
	for _, endpoint := range endpoints {
		path := endpoint.Path
		options := terratest_http_helper.HttpGetOptions{Url: path, TlsConfig: &tlsConfig, Timeout: 10}
		expectedBody := ""
		if endpoint.ExpectedBody != nil {
			expectedBody = *endpoint.ExpectedBody
		}
		maxRetries := 5
		if endpoint.MaxRetries != nil {
			maxRetries = *endpoint.MaxRetries
		}
		sleepBetweenRetries := 30 * time.Second
		if endpoint.SleepBetweenRetries != nil {
			sleepBetweenRetries = *endpoint.SleepBetweenRetries
		}
		for i := 0; i <= maxRetries; i++ {
			if endpoint.Command != nil {
				command := terratestShell.Command{
					Command: "bash",
					Args:    []string{"-c", util.Value(endpoint.Command)},
				}
				output := strings.TrimSpace(terratestShell.RunCommandAndGetOutput(t, command))
				terratestLogger.Log(t, output)
				if err := util.FindE(fmt.Sprintf("%d", endpoint.ExpectedStatus), output); err == nil {
					terratestLogger.Log(t, `Command successful`)
					return
				}
				if i == maxRetries {
					t.Fatalf(`'Command' unsuccessful after %d retries`, maxRetries)
				}
			} else {
				gotStatus, gotBody := terratest_http_helper.HttpGetWithOptions(t, options)
				terratestLogger.Log(t, fmt.Sprintf(`
					got status:: %d
					expected status:: %d
					`, gotStatus, endpoint.ExpectedStatus))
				if endpoint.ExpectedBody != nil {
					terratestLogger.Log(t, fmt.Sprintf(`
					got body:: %s
					expected body:: %s
					`, gotBody, expectedBody))
				}
				if gotStatus == endpoint.ExpectedStatus && (endpoint.ExpectedBody == nil || (endpoint.ExpectedBody != nil && gotBody == expectedBody)) {
					terratestLogger.Log(t, `'HTTP GET to URL %s' successful`, path)
					return
				}
				if i == maxRetries {
					t.Fatalf(`'HTTP GET to URL %s' unsuccessful after %d retries`, path, maxRetries)
				}
			}

			terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
			time.Sleep(sleepBetweenRetries)
		}
	}
}

func ValidateGrpcEndpoints(t *testing.T, microservicePath string, deployment DeploymentTest, traffics []Traffic, name, modulePath string) {
	terratestLogger.Log(t, "Validate gRPC endpoints")
	sleepBetweenRetries := 30 * time.Second
	terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
	time.Sleep(sleepBetweenRetries)

	for _, traffic := range traffics {
		terratestLogger.Log(t, "protocol", traffic.Listener.Protocol)

		port := util.Value(traffic.Listener.Port, 443)

		route53 := ExtractFromState(t, microservicePath, "ecs.route53")
		terratestLogger.Log(t, fmt.Sprintf("route53 :: %+v", route53))
		if route53 != nil {
			recordName := route53.(map[string]any)["records"].(map[string]any)[fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))].(map[string]any)["name"].(map[string]any)[name+" A"].(string)
			route53DnsUrl := fmt.Sprintf("%s:%d", recordName, port)
			fmt.Printf("\n\nRoute53 DNS = %s\n\n", route53DnsUrl)

			endpointsLoadBalancer := []EndpointTest{}
			for _, endpoint := range deployment.Endpoints {
				newEndpoint := endpoint

				if endpoint.Command != nil {
					re := regexp.MustCompile(`<URL>`)
					newEndpoint.Command = util.Ptr(re.ReplaceAllString(util.Value(endpoint.Command), route53DnsUrl))
				}

				endpointsLoadBalancer = append(endpointsLoadBalancer, newEndpoint)
			}
			terratestStructure.RunTestStage(t, "validate_grpc_endpoints_load_balancer", func() {
				TestGrpcEndpoints(t, endpointsLoadBalancer, route53DnsUrl)
			})
		}
	}
}

func TestGrpcEndpoints(t *testing.T, endpoints []EndpointTest, address string) {
	for _, endpoint := range endpoints {
		maxRetries := 5
		if endpoint.MaxRetries != nil {
			maxRetries = *endpoint.MaxRetries
		}
		sleepBetweenRetries := 30 * time.Second
		if endpoint.SleepBetweenRetries != nil {
			sleepBetweenRetries = *endpoint.SleepBetweenRetries
		}
		for i := 0; i <= maxRetries; i++ {
			if endpoint.Command != nil {
				command := terratestShell.Command{
					Command: "bash",
					Args:    []string{"-c", util.Value(endpoint.Command)},
				}
				output := strings.TrimSpace(terratestShell.RunCommandAndGetOutput(t, command))
				terratestLogger.Log(t, output)
				if i == maxRetries {
					t.Fatalf(`'Command' unsuccessful after %d retries`, maxRetries)
				}
			} else {
				paths := strings.Split(strings.TrimPrefix(endpoint.Path, "/"), "/")
				service := paths[0]
				method := paths[1]

				// cmd := fmt.Sprintf("wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_%s.tar.gz -q; tar -xzvf grpcurl_1.8.7_linux_%s.tar.gz grpcurl; ./grpcurl -plaintext %s %s/%s", util.GetEnvVariable("ARCH"), util.GetEnvVariable("ARCH"), address, service, method)

				request := util.Value(endpoint.Request, "{}")
				cmd := fmt.Sprintf("curl -L https://github.com/vadimi/grpc-client-cli/releases/download/v1.18.0/grpc-client-cli_linux_%s.tar.gz | tar -xz; echo '%s' | ./grpc-client-cli -service %s -method %s %s", util.GetEnvVariable("ARCH"), request, service, method, address)

				command := terratestShell.Command{
					Command: "bash",
					Args:    []string{"-c", cmd},
				}
				output := strings.TrimSpace(terratestShell.RunCommandAndGetOutput(t, command))
				terratestLogger.Log(t, output)
				if i == maxRetries {
					t.Fatalf(`gRPC unsuccessful after %d retries`, maxRetries)
				}
			}

			terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
			time.Sleep(sleepBetweenRetries)
		}
	}
}
