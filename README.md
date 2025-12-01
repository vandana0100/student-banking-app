# Pixel River Financial Bank Application
## Student: Vandana Bhangu
## GitHub: [vandana0100](https://github.com/vandana0100)

# Project Overview
The Student Portfolio Microservice aims to provide a platform where students can showcase their projects, skills, and academic achievements. It's built with scalability and modularity in mind, allowing for independent development and deployment of the frontend and backend components.

This banking microservice application demonstrates modern DevOps practices including Docker containerization, Kubernetes orchestration, CI/CD pipelines, and GitOps deployment strategies.

## Architecture
**The application follows a simple microservice pattern:**

## Frontend: A client-side application (e.g., React, Angular, Vue.js) responsible for the user interface and interactions.

    Frontend: A client-side application (e.g., React, Angular, Vue.js) responsible for the user interface and interactions.

    Backend: A server-side application (e.g., Node.js with Express, Python with Flask/Django, Java with Spring Boot) that handles business logic, API requests, and interacts with the database.

    Transactions: A service specifically for managing and processing all financial transactions related to student portfolios, such as payments for premium features or certifications.

    Nginx: Serves as the entry point for all incoming HTTP requests. It acts as a reverse proxy, directing requests to either the frontend static files or proxying API calls to the backend service.

    MongoDB: A NoSQL database used by the backend service to store all application data (e.g., student profiles, project details, skills).


+------------------+     +-------------------+     +-------------------+     +--------------+
|      Client      | <-> |   Nginx (Port 80) | <-> |     Frontend      |     |              |
| (Web Browser)    |     | (Reverse Proxy)   |     | (Static Files)    |     |              |
+------------------+     +-------------------+     +-------------------+     |   MongoDB    |
                                   |                                         |  (Database)  |
                                   | API Calls (via Nginx reverse proxy)     |              |
                                   v                                         |              |
                                +-------------------+ <---------------------+--------------+
                                |      Backend      |
                                |   (API Service)   |
                                +-------------------+
                                          |
                                          |
                                          v
                                +-----------------------+
                                |      Transactions     |
                                | (Payment Processing)  |
                                +-----------------------+
## Technologies Used
    Frontend: HTML/CSS/JavaScript (Student Portfolio)

    Backend: Python with Flask (Banking API)

    Transactions: Node.js with Express (Transactions Microservice)

    Database: MongoDB

    API Proxy/Web Server: Nginx

    Containerization: Docker, Docker Compose (for local development)

    Orchestration: Kubernetes (Minikube for local, EKS for cloud)

    CI/CD: GitHub Actions

    GitOps: ArgoCD



