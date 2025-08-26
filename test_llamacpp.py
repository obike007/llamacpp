import requests
import json
import sys

def test_llamacpp():
    url = "http://localhost:8083/completion"
    payload = {
        "prompt": "What is artificial intelligence?",
        "n_predict": 100,
        "temperature": 0.7,
        "stop": ["\n"]
    }
    
    try:
        response = requests.post(url, json=payload, timeout=30)
        response.raise_for_status()
        print(json.dumps(response.json(), indent=2))
        return 0
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot connect to {url}", file=sys.stderr)
        return 1
    except requests.exceptions.Timeout:
        print("Error: Request timed out", file=sys.stderr)
        return 1
    except requests.exceptions.HTTPError as e:
        print(f"HTTP Error: {e}", file=sys.stderr)
        print(f"Response: {response.text}", file=sys.stderr)
        return 1
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON response: {response.text}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(test_llamacpp())