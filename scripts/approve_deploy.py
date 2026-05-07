from flask import Flask, request
import requests
import json

app = Flask(__name__)

@app.route('/approve')
def approve():

    service = request.args.get("service")

    payload = {
        "apiVersion": "tekton.dev/v1",
        "kind": "PipelineRun",
        "metadata": {
            "generateName": "deploy-run-",
            "namespace": "cp4i"
        },
        "spec": {

            "pipelineRef": {
                "name": "ace-deploy-pipeline"
            },

            "workspaces": [
                {
                    "name": "shared-workspace",
                    "persistentVolumeClaim": {
                        "claimName": "ace-pipeline-pvc"
                    }
                }
            ]
        }
    }

    # =====================================================
    # Read ServiceAccount Token
    # =====================================================

    token = open(
        "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ).read()

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # =====================================================
    # Trigger Tekton PipelineRun
    # =====================================================

    response = requests.post(
        "https://kubernetes.default.svc/apis/tekton.dev/v1/namespaces/cp4i/pipelineruns",
        headers=headers,
        verify=False,
        json=payload
    )

    # =====================================================
    # Debug Logs
    # =====================================================

    print("=================================")
    print("PIPELINE RESPONSE STATUS")
    print(response.status_code)
    print("=================================")

    print("=================================")
    print("PIPELINE RESPONSE BODY")
    print(response.text)
    print("=================================")

    # =====================================================
    # Success / Failure Response
    # =====================================================

    if response.status_code in [200, 201, 202]:

        response_json = response.json()

        pipeline_run_name = response_json["metadata"]["name"]

        return f"""
Deployment Pipeline Triggered Successfully

PipelineRun:
{pipeline_run_name}

Service:
{service}
"""

    else:

        return f"""
Pipeline Trigger Failed

Status Code:
{response.status_code}

Response:
{response.text}
"""


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
