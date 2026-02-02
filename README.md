# Aryon DevOps Take-Home Assignment

## Goal

Your goal is to demonstrate your ability to containerize applications and deploy them to Kubernetes using cloud-native tooling and best practices.

## The Assignment

You have been provided with two Python Flask microservices:
- **Items Service** - A public-facing REST API that manages items
- **Audit Service** - An internal service that logs all operations

Your task is to:
* Build a small Kubernetes test cluster either locally or in the cloud. A single node is fine. Feel free to use Terraform with a cloud provider or an all-in-one tool for a local cluster
* Build Docker files for both sample applications (applications must return correct results)
* Build a deployment mechanism for these apps
* Describe a plan for continuous delivery with the specific tools/vendors you'd look at and your evaluation criteria for them

## Architecture

The Items Service should:
- Be publicly accessible
- Store items in a PostgreSQL database
- Send audit events to the Audit Service for every operation

The Audit Service should:
- Be internal only (not publicly accessible)
- Receive audit events from the Items Service
- Store audit logs in the same PostgreSQL database

## What's Provided

- Working Python applications (`items-service/app.py`, `audit-service/app.py`)
- Python dependencies (`requirements.txt` for each service)
- Database schema (`database/schema.sql`)

## Deliverables

We'd like to see a repo with the following:

1. **Dockerfiles** for both applications
2. **Repeatable deployment mechanism** for each application
3. **PostgreSQL deployment** and also initialize the schema with provided `schema.sql` file
4. **README** with set-up instruction so we can easily test things out ourselves
5. **Include a write up** - a text file with a brief write up about the following:
   - CD strategy 
   - Tools chosen and why

## Bonus Points - add monitoring capabilities to the services

**Custom Metrics Support**
  - Implement application metrics using Prometheus client library
  - Expose custom metrics such as:
    - Total number of items created/retrieved
    - Audit log events processed
    - API request latency
    - Database query performance
  - Deploy Prometheus and Grafana to the cluster
  - Create a dashboard to visualize the custom metrics

## Notes

- Feel free to change the python application code and/or their requirements to make them more "cloud native"
- Don't worry about reaching out if you are stuck/need more clarity
- Have fun!

## Time Expectation

This should take approximately **3 hours** to complete. If you find yourself spending significantly more time, that's okay - just document what you accomplished and what you would do with more time.

## Getting Started Locally

```bash
# Install dependencies locally (for development/testing)
cd items-service
pip install -r requirements.txt

cd ../audit-service
pip install -r requirements.txt

# Review the applications
# Check database/schema.sql for the database structure
```

Once deployed, your application should support:

```bash
# Create an item
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Testing"}'

# List items
curl http://localhost:8080/items

# Verify audit logs in the database
kubectl exec -it <postgres-pod> -- psql -U postgres -d itemsdb \
  -c "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 5;"
```

Good luck! 🚀
