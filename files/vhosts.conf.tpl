{{ $domains := tree "letsencrypt" | byKey }}{{ range $domain, $pairs := $domains }}
{{ with $upstream := printf "letsencrypt/%s/upstream" $domain }}
{{ with $upstream_type_path := printf "letsencrypt/%s/upstream_type" $domain }}
{{ with $upstream_type := key $upstream_type_path }}
upstream {{ printf $domain }}_upstream {
    {{ key $upstream }}
}

server {
    server_name {{ printf $domain }};
    listen 443 ssl;
    ssl_certificate /usr/local/etc/nginx/certs/{{ printf $domain }}.cert.pem;
    ssl_certificate_key /usr/local/etc/nginx/certs/{{ printf $domain }}.privkey.pem;

    root /usr/local/www/{{ printf $domain }};
    access_log /var/log/nginx/{{ printf $domain }}.log;
    error_log /var/log/nginx/{{ printf $domain }}.err;

    location ~ /\.ht {
        deny all;
    }

{{ if eq $upstream_type "php" }}
    index index.html index.htm index.php;
    location / {
        try_files $uri $uri/ index.php;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass {{ printf $domain }}_upstream;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        set $path_info $fastcgi_path_info;
        fastcgi_param PATH_INFO $path_info;
        fastcgi_param SCRIPT_FILENAME /usr/local/www/rainloop$fastcgi_script_name;
        fastcgi_index index.php;
    }
{{ else if eq $upstream_type "uwsgi" }}
    index index.html index.htm;
    location / {
        include uwsgi_params;
        uwsgi_pass {{ printf $domain }}_upstream;
        uwsgi_param Host $host;
        uwsgi_param X-Real-IP $remote_addr;
        uwsgi_param X-Forwarded-For $proxy_add_x_forwarded_for;
        uwsgi_param X-Forwarded-Proto $http_x_forwarded_proto;
    }
{{ else if eq $upstream_type "fcgi" }}
    index index.html index.htm;

    location / {
        return 301 /cgi-bin/listinfo;
    }

    location /pipermail {
        autoindex on;
        alias /usr/local/mailman/archives/public;
    }

    location /cgi-bin {
        root /usr/local/mailman;
        include fastcgi_params;
        fastcgi_split_path_info (^/cgi-bin/mailman/[^/]*)(.*)$;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
        fastcgi_intercept_errors on;
        fastcgi_pass {{ printf $domain }}_upstream;
    }
{{ end }}
}
{{ end }}{{ end }}{{ end }}{{ end }}
