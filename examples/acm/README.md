# ACM example with the microservice

This will create a certificate for HTTPS.
Do do so add in the traffics a listener with https, by default the port used is 443.
There is one traffic element which is the base, wither it is by default because it is the only element in traffics, or the base must be set to `true`. In that traffic element, the port must be set.