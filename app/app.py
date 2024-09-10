from http.client import BAD_REQUEST
import boto3, flask
from dataclasses import dataclass, asdict, field
from typing import List, Dict, Any
from flask import Flask, request, jsonify
from botocore.exceptions import ClientError

app = Flask(__name__)

# Setup DynamoDB config
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
user_table = dynamodb.Table('Users')
group_table = dynamodb.Table('Groups')


@dataclass
class User:
    name: str
    region: str
    email: str
    age: str
    group: str

    def to_json(self) -> Dict[str, Any]:
        return asdict(self)
    
    @classmethod
    def from_json(cls, data: Dict[str, Any]) -> 'User':
        return cls(**data)


@dataclass
class Group:
    name: str
    region: str
    users: List[User] = field(default_factory=list)

    def to_json(self) -> Dict[str, Any]:
        group_data = asdict(self)
        group_data['users'] = [user.to_json() for user in self.users]
        return group_data
    
    @classmethod
    def from_json(cls, data: Dict[str, Any]) -> 'Group':
        users = [User.from_json(user) for user in data.get('users', [])]
        return cls(name=data['name'], region=data['region'], users=users)

def post_user(data: Dict[str, Any]):
    try:
        new_user = User.from_json(data)
        
        # Insert user on table
        user_table.put_item(Item=new_user.to_json())
        
        # Checking if user exists
        response = group_table.get_item(Key={'name': new_user.group})
        if 'Item' in response:
            # Update existing group
            group_table.update_item(
                Key={'name': new_user.group},
                UpdateExpression="SET users = list_append(users, :new_user)",
                ExpressionAttributeValues={':new_user': [new_user.to_json()]},
                ReturnValues="UPDATED_NEW"
            )
        else:
            # Create new group
            new_group = Group(name=new_user.group, region=new_user.region, users=[new_user])
            group_table.put_item(Item=new_group.to_json())
    
    except KeyError as ex:
        raise BAD_REQUEST(f"Missing field in input data: {str(ex)}")
    except ClientError as ex:
        return {'ERROR': f'An error occurred while trying to interact with DynamoDB: {str(ex)}'}, 500
    except Exception as ex:
        return {'ERROR': f'An error occurred while trying to insert a new user: {str(ex)}'}, 500

@app.route('/')
def home():
    return "Hello, welcome!"

@app.route('/users', methods=['GET'])
def get_users():
    try:
        response = user_table.scan()
        users = response.get('Items', [])
        user_list = [User.from_json(usr).to_json() for usr in users]
        return jsonify(user_list)
    except ClientError as ex:
        return {'ERROR': f'An error occurred while trying to get users from DynamoDB: {str(ex)}'}, 500
    except Exception as ex:
        return {'ERROR': f'An error occurred while trying to get users: {str(ex)}'}, 500

@app.route('/users/<name>', methods=['GET'])
def get_user_by_name(name: str):
    try:
        response = user_table.get_item(Key={'name': name})
        if 'Item' in response:
            return jsonify(User.from_json(response['Item']).to_json())
        return {'ERROR': 'User not found.'}, 404
    except ClientError as ex:
        return {'ERROR': f'An error occurred while trying to get user from DynamoDB: {str(ex)}'}, 500
    except Exception as ex:
        return {'ERROR': f'An error occurred while trying to get user: {str(ex)}'}, 500

@app.route('/groups', methods=['GET'])
def get_groups():
    try:
        response = group_table.scan()
        groups = response.get('Items', [])
        group_list = [Group.from_json(grp).to_json() for grp in groups]
        return jsonify(group_list)
    except ClientError as ex:
        return {'ERROR': f'An error occurred while trying to get groups from DynamoDB: {str(ex)}'}, 500
    except Exception as ex:
        return {'ERROR': f'An error occurred while trying to get groups: {str(ex)}'}, 500

@app.route('/groups/<name>', methods=['GET'])
def get_group_by_name(name: str):
    try:
        response = group_table.get_item(Key={'name': name})
        if 'Item' in response:
            return jsonify(Group.from_json(response['Item']).to_json())
        return {'ERROR': 'Group not found.'}, 404
    except ClientError as ex:
        return {'ERROR': f'An error occurred while trying to get group from DynamoDB: {str(ex)}'}, 500
    except Exception as ex:
        return {'ERROR': f'An error occurred while trying to get group: {str(ex)}'}, 500

@app.route('/subscribe', methods=['POST'])
def subscribe():
    try:
        data = request.get_json()
        if data is None:
            return jsonify({'ERROR': 'No JSON document was provided'}), 400

        post_user(data)
        return "New user subscribed!"
    except BAD_REQUEST as ex:
        return {'ERROR': str(ex)}, 400
    except Exception as ex:
        return {'ERROR': f'An error occurred during the process: {str(ex)}'}, 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080)
