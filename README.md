# Student Banking Microservices Application

**Author:** Vandana Bhangu  
**GitHub:** [vandana0100](https://github.com/vandana0100)  
**Repository:** [student-banking-app](https://github.com/vandana0100/student-banking-app)

## Project Overview

This project represents my evolution from Module 3's simple static portfolio page to a comprehensive, production-ready microservices-based banking application. The Student Banking Microservice provides a platform where students can manage their banking transactions, with secure authentication, real-time balance tracking, and transaction history. It's built with scalability and modularity in mind, allowing for independent development and deployment of each microservice component.

## Project Evolution

**Module 3:** Started with a basic static HTML portfolio page served by a simple Node.js Express server.

**Module 5 Part 3:** Evolved into a full microservices architecture featuring:
- Containerized services with Docker
- Kubernetes orchestration for deployment and scaling
- NGINX reverse proxy for routing and load balancing
- MongoDB database for persistent data storage
- RESTful API communication between services
- Secure user authentication and session management
- Transaction processing microservice
- Automated testing and CI/CD workflows

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

- **Frontend:** HTML5, CSS3, JavaScript, Bootstrap 5.3.3
- **Backend:** Python 3.x with Flask, Flask-PyMongo
- **Transactions Service:** Node.js with Express.js
- **Database:** MongoDB 6.x (NoSQL document database)
- **API Proxy/Web Server:** NGINX (Alpine Linux)
- **Containerization:** Docker, Docker Compose (for local development)
- **Orchestration:** Kubernetes (Minikube for local, production-ready configurations)
- **Testing:** pytest, Flask testing framework
- **Version Control:** Git, GitHub
- **CI/CD:** GitHub Actions (workflows excluded from initial push)



