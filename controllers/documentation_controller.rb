class DocumentationController < ApplicationController
  get '/mod-api/doc/api' do
    content_type 'text/html'
    <<-HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8" />
            <title>MOD-API Documentation</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui.min.css" />
          </head>
          <body>
            <div id="swagger-ui"></div>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui-bundle.min.js"></script>
            <script>
              window.onload = () => {
                window.ui = SwaggerUIBundle({
                  url: '/openapi.json',
                  dom_id: '#swagger-ui',
                });
              };
            </script>
          </body>
          </html>
        HTML
  end

  # Serve OpenAPI JSON
  get '/openapi.json' do
    content_type :json
    generate_openapi_json.to_json
  end
end
