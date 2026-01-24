# Stage 1: Builder
FROM python:3.6-alpine AS builder

WORKDIR /opt

# Install build dependencies
RUN apk add --no-cache gcc musl-dev

# Install Python dependencies
RUN pip install --user --no-cache-dir flask

# Stage 2: Production
FROM python:3.6-alpine AS final

LABEL maintainer="lagazakevin@gmail.com" \
      description="IC Webapp - Intranet applications display"

WORKDIR /opt

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Create environment variables
ENV ODOO_URL=""
ENV PGADMIN_URL=""

# Copy application files
COPY app.py .
COPY templates/ ./templates/

# Expose port
EXPOSE 8080

# Run application
ENTRYPOINT ["python", "app.py"]

