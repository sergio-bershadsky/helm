worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile    on;
    tcp_nopush  on;
    keepalive_timeout 65;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    {{- if .Values.nginx.cors.enabled }}
    map $http_origin $cors_origin {
        default "";
        {{- range .Values.nginx.cors.origins }}
        {{ . | quote }}  $http_origin;
        {{- end }}
    }
    {{- end }}

    {{- if .Values.nginx.gzip.enabled }}
    gzip on;
    gzip_types text/css text/scss text/plain text/xml application/xml application/json application/javascript;
    {{- end }}

    # Default server — health checks and catch-all
    server {
        listen 80 default_server;
        server_name _;

        location /healthz {
            access_log off;
            return 200 "ok\n";
        }

        location / {
            return 444;
        }
    }

    {{- if .Values.nginx.domains.public.host }}
    # Public domain — frontend + API
    server {
        listen 80;
        server_name {{ .Values.nginx.domains.public.host }};

        proxy_read_timeout    {{ .Values.nginx.timeouts.proxy_read }};
        proxy_connect_timeout {{ .Values.nginx.timeouts.proxy_connect }};
        proxy_send_timeout    {{ .Values.nginx.timeouts.proxy_send }};
        client_max_body_size  {{ .Values.nginx.clientMaxBodySize }};

        {{- if .Values.nginx.maintenancePage.enabled }}
        error_page 502 503 504 /maintenance.html;
        location = /maintenance.html {
            root /usr/share/nginx/html;
            internal;
        }
        {{- end }}

        location /api/ {
            proxy_http_version 1.1;
            proxy_pass http://{{ include "odoo.backend.serviceName" . }}:{{ .Values.backend.service.ports.http }};
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Real-IP $remote_addr;

            {{- if .Values.nginx.cookieSecure }}
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            {{- end }}
            proxy_cookie_flags session_id samesite=lax{{ if .Values.nginx.cookieSecure }} secure{{ end }};

            {{- if .Values.nginx.cors.enabled }}
            add_header Access-Control-Allow-Origin $cors_origin always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Authorization, Content-Type, Accept" always;
            add_header Access-Control-Allow-Credentials "true" always;

            if ($request_method = OPTIONS) {
                return 204;
            }
            {{- end }}
        }

        location / {
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_redirect off;
            proxy_pass http://{{ include "odoo.frontend.serviceName" . }}:{{ .Values.frontend.service.port }};

            {{- if .Values.nginx.cookieSecure }}
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            {{- end }}
            proxy_cookie_flags session_id samesite=lax{{ if .Values.nginx.cookieSecure }} secure{{ end }};
        }
    }
    {{- end }}

    {{- if and .Values.nginx.domains.backoffice.enabled .Values.nginx.domains.backoffice.host }}
    # Backoffice domain — Odoo admin + WebSocket
    server {
        listen 80;
        server_name {{ .Values.nginx.domains.backoffice.host }};

        proxy_read_timeout    {{ .Values.nginx.timeouts.proxy_read }};
        proxy_connect_timeout {{ .Values.nginx.timeouts.proxy_connect }};
        proxy_send_timeout    {{ .Values.nginx.timeouts.proxy_send }};
        client_max_body_size  {{ .Values.nginx.clientMaxBodySize }};

        {{- if .Values.nginx.maintenancePage.enabled }}
        error_page 502 503 504 /maintenance.html;
        location = /maintenance.html {
            root /usr/share/nginx/html;
            internal;
        }
        {{- end }}

        # WebSocket — Odoo gevent port
        location /websocket {
            proxy_http_version 1.1;
            proxy_pass http://{{ include "odoo.backend.serviceName" . }}:{{ .Values.backend.service.ports.websocket }};
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Real-IP $remote_addr;

            {{- if .Values.nginx.cookieSecure }}
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            {{- end }}
            proxy_cookie_flags session_id samesite=lax{{ if .Values.nginx.cookieSecure }} secure{{ end }};
        }

        # Odoo backend
        location / {
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_redirect off;
            proxy_pass http://{{ include "odoo.backend.serviceName" . }}:{{ .Values.backend.service.ports.http }};

            {{- if .Values.nginx.cookieSecure }}
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            {{- end }}
            proxy_cookie_flags session_id samesite=lax{{ if .Values.nginx.cookieSecure }} secure{{ end }};
        }
    }
    {{- end }}
}
