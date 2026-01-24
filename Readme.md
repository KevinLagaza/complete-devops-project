# COMPLETE DEVOPS PROJECT 

## **Context**

The company **IC GROUP**, where I work as a DevOps engineer, wants to set up a showcase website that provides access to its 2 flagship applications:

1) Odoo
2) pgAdmin

**Odoo** is a multi-purpose ERP that manages sales, purchases, accounting, inventory, personnel, and more.
Odoo is distributed in both Community and Enterprise editions. ICGROUP wants to have control over the code and make its own modifications and customizations, so they opted for the Community edition. Several versions of Odoo are available, and version 13.0 was chosen because it includes an LMS (Learning Management System) that will be used to publish internal training courses and share information more easily.
Useful links:

- Official website: [ https://www.odoo.com/ ](https://www.odoo.com/) 
- Official GitHub: [ https://github.com/odoo/odoo.git ](https://github.com/odoo/odoo.git)
- Official Docker Hub: [ https://hub.docker.com/_/odoo ](https://hub.docker.com/_/odoo)

**pgAdmin** will be used to graphically administer the PostgreSQL database created previously.

- Official website: [ https://www.pgadmin.org/ ](https://www.pgadmin.org/) 
- Official Docker Hub: [ https://hub.docker.com/r/dpage/pgadmin4/ ](https://hub.docker.com/r/dpage/pgadmin4/)

## **Part 1: Contenerization of the web app** 

The showcase website was designed by the company's development team. It is my responsibility to containerize this application while allowing the input of the different application URLs (Odoo and pgAdmin) through environment variables.

1) **Build and test**

- docker build -t ic-webapp:1.0 .
- docker images
- docker run -d \
    --name test-ic-webapp \
    -p 8080:8080 \
    -e ODOO_URL="http://odoo.example.com" \
    -e PGADMIN_URL="http://pgadmin.example.com" \
    ic-webapp:1.0
- docker ps

**![Docker build](./images/docker-build.png)**

**![Docker run](./images/docker-run.png)**

**![Test dockerfile](./images/app-test-container.png)**

2) **Push image to Docker Hub**
- docker rm -f test-ic-webapp
- docker tag ic-webapp:1.0 kevinlagaza/ic-webapp:1.0
- docker login (enter username and password)
- docker push kevinlagaza/ic-webapp:1.0 

**![Pushing to DockerHub](./images/pushing-to-dockerhub.png)**

**![Inside DockerHub](./images/inside-dockerhub.png)**

## **Part 2 : CI/CD pipeline with JENKINS and ANSIBLE** 
ICGROUP's objective is to set up a CI/CD pipeline enabling continuous integration and deployment of this solution across their different machines in the production environment (3 servers hosted in AWS cloud).






