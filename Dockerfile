# Stage 1: Builder
FROM python:3.6-alpine AS builder

WORKDIR /opt

# Install build dependencies
RUN apk add --no-cache gcc musl-dev

# Install Python dependencies
RUN pip install --user --no-cache-dir flask

# Stage 2: Production
FROM python:3.11-slim AS final

LABEL maintainer="lagazakevin@gmail.com" \
      description="IC Webapp - Intranet applications display"

WORKDIR /opt

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy releases.txt and extract environment variables
COPY releases.txt .

# Extract values using awk and set as environment variables
RUN ODOO_URL=$(awk -F': ' '/^ODOO_URL:/ {print $2}' releases.txt) && \
    PGADMIN_URL=$(awk -F': ' '/^PGADMIN_URL:/ {print $2}' releases.txt) && \
    # echo "ODOO_URL=$ODOO_URL" >> /etc/environment && \
    # echo "PGADMIN_URL=$PGADMIN_URL" >> /etc/environment
    && echo "ODOO_URL=$ODOO_URL" > /opt/env.sh \
    && echo "PGADMIN_URL=$PGADMIN_URL" >> /opt/env.sh

# Set environment variables using ARG and ENV
# ARG ODOO_URL_ARG
# ARG PGADMIN_URL_ARG
# ENV ODOO_URL=${ODOO_URL_ARG}
# ENV PGADMIN_URL=${PGADMIN_URL_ARG}

# Copy application files
COPY app.py .
COPY templates/ ./templates/

# Expose port
EXPOSE 8080

# Run application
# ENTRYPOINT ["python", "app.py"]
CMD ["/bin/sh", "-c", ". /opt/env.sh && export ODOO_URL PGADMIN_URL && python app.py"]