################################################################################
# Envoy Static Bootstrap Configuration
#
# This is a basic starting point. For dynamic config, migrate to xDS/ADS
# with a control plane (see backlog.md for evolution roadmap).
################################################################################

%{ if enable_admin_interface ~}
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: ${admin_port}
%{ endif ~}

static_resources:
  listeners:
    - name: main_listener
      address:
        socket_address:
          address: 0.0.0.0
          port_value: ${listener_port}
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: catch_all
                      domains: ["*"]
                      routes:
                        # Health check route
                        - match:
                            prefix: "/healthz"
                          direct_response:
                            status: 200
                            body:
                              inline_string: "OK"

                        # Example: route /api/inference/* to an inference backend
                        - match:
                            prefix: "/api/inference"
                          route:
                            cluster: inference_backend
                            timeout: 60s

                        # Default: 404 for unmatched routes
                        - match:
                            prefix: "/"
                          direct_response:
                            status: 404
                            body:
                              inline_string: '{"error": "route not configured"}'

                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
    # Default inference backend cluster
    - name: inference_backend
      type: STRICT_DNS
      connect_timeout: 5s
      lb_policy: ROUND_ROBIN
      load_assignment:
        cluster_name: inference_backend
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: vllm.inference.svc.cluster.local
                      port_value: 8000

%{ for name, cluster in upstream_clusters ~}
    - name: ${name}
      type: STRICT_DNS
      connect_timeout: 5s
      lb_policy: ROUND_ROBIN
      load_assignment:
        cluster_name: ${name}
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: ${cluster.address}
                      port_value: ${cluster.port}
%{ endfor ~}
