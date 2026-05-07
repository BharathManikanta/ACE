from flask import Flask, request
import requests

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
            }
        }
    }

    token = open(
        "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ).read()

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    response = requests.post(
        "https://kubernetes.default.svc/apis/tekton.dev/v1/namespaces/cp4i/pipelineruns",
        headers=headers,
        verify=False,
        json=payload
    )

    return "Deployment Triggered Successfully"


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
