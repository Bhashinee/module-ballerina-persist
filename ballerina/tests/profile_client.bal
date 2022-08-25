// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerinax/mysql;
import ballerina/sql;

client class ProfileClient {

    private final string entityName = "Profile";
    private final sql:ParameterizedQuery tableName = `Profiles`;
    private final map<FieldMetadata> fieldMetadata = {
        id: {columnName: "id", 'type: int},
        name: {columnName: "name", 'type: string},
        "user.id": {columnName: "userId", 'type: int, relation: {entityName: "user", refTable: "Users", refField: "id"}},
        "user.name": {'type: int, relation: {entityName: "user", refTable: "Users", refField: "name"}}
    };
    private string[] keyFields = ["id"];
    private final map<JoinMetadata> joinMetadata = {
        user: {refTable: "Users", refFields: ["id"], joinColumns: ["userId"]}
    };

    private SQLClient persistClient;

    public function init() returns error? {
        mysql:Client dbClient = check new (host = HOST, user = USER, password = PASSWORD, database = DATABASE, port = PORT);
        self.persistClient = check new (self.entityName, self.tableName, self.fieldMetadata, self.keyFields, dbClient, self.joinMetadata);
    }

    remote function create(Profile value) returns Profile|error {
        if value.user is User {
            UserClient userClient = check new UserClient();
            boolean exists = check userClient->exists(check value.user.ensureType(User));
            if !exists {
                value.user = check userClient->create(check value.user.ensureType(User));
            }
        }
    
        sql:ExecutionResult result = check self.persistClient.runInsertQuery(value);

        int key;
        if result.lastInsertId is () {
            key = value.id;
        } else {
            key = <int> result.lastInsertId;
        }

        return check self->readByKey(key);
    }

    remote function readByKey(int key, ProfileRelations[] include = []) returns Profile|error {
        Profile profile = <Profile> check self.persistClient.runReadByKeyQuery(Profile, include, key);
        return profile;
    }

    remote function read(map<anydata>? filter = (), ProfileRelations[] include = []) returns stream<Profile, error?>|error {
        stream<anydata, error?> result = check self.persistClient.runReadQuery(filter);
        return new stream<Profile, error?>(new ProfileStream(result, include));
    }

    remote function update(record {} 'object, map<anydata> filter) returns error? {
        _ = check self.persistClient.runUpdateQuery('object, filter);
    }

    remote function delete(map<anydata> filter) returns error? {
        _ = check self.persistClient.runDeleteQuery(filter);
    }

    remote function exists(Profile profile) returns boolean|error {
        Profile|error result = self->readByKey(profile.id);
        if result is Profile {
            return true;
        } else if result is InvalidKey {
            return false;
        } else {
            return result;
        }
    }

    function close() returns error? {
        return self.persistClient.close();
    }

}

public enum ProfileRelations {
    user
}

public class ProfileStream {
    private stream<anydata, error?> anydataStream;
    private ProfileRelations[] include;

    public isolated function init(stream<anydata, error?> anydataStream, ProfileRelations[] include = []) {
        self.anydataStream = anydataStream;
        self.include = include;
    }

    public isolated function next() returns record {|Profile value;|}|error? {
        var streamValue = self.anydataStream.next();
        if streamValue is () {
            return streamValue;
        } else if (streamValue is error) {
            return streamValue;
        } else {
            record {|Profile value;|} nextRecord = {value: <Profile>streamValue.value};
            return nextRecord;
        }
    }

    public isolated function close() returns error? {
        return self.anydataStream.close();
    }
}
