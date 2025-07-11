const { Signer } = require("@aws-sdk/rds-signer");
const { GetParameterCommand, SSMClient } = require("@aws-sdk/client-ssm");
const mysql = require("mysql2/promise");

const region = "ap-northeast-2";
const ssmClient = new SSMClient({ region });

let hostName, dbUserName, database;
let initialized = false;

async function init() {
  if (initialized) return; // 여러 번 호출되지 않도록 방지
  try {
    [hostName, dbUserName, database] = await Promise.all([
      getParam("/finguard/dev/finance/rds_proxy_hostname", false),
      getParam("/finguard/dev/finance/rds_db_username", false),
      getParam("/finguard/dev/finance/rds_db_name", false),
    ]);
    initialized = true;
  } catch (err) {
    console.error("SSM 파라미터 조회 실패:", err);
    throw err; // Lambda가 실패하도록 에러 전파
  }
}

async function getParam(name, withDecryption) {
  const input = {
    Name: name,
    WithDecryption: withDecryption,
  };

  const command = new GetParameterCommand(input);
  const response = await ssmClient.send(command);
  return response.Parameter.Value;
}

async function createAuthToken() {
  const signer = new Signer({
    region,
    hostname: hostName,
    port: 3306,
    username: dbUserName,
  });

  return signer.getAuthToken();
}

async function dbOps() {
  await init(); // 파라미터 미리 초기화
  console.log("DB 연결 시작");
  const token = await createAuthToken();

  console.log("hostName: ", hostName);
  console.log("dbUserName: ", dbUserName);
  console.log("token: ", token);
  console.log("database: ", database);
  console.log("region: ", region);

  const connectionConfig = {
    host: hostName,
    user: dbUserName,
    password: token,
    database: database,
    ssl: {
      rejectUnauthorized: true,
    },
  };

  const conn = await mysql.createConnection({
    host: hostName,
    user: dbUserName,
    password: token,
    database: database,
    ssl: "Amazon RDS",
    port: 3306,
    authPlugins: {
      mysql_clear_password: () => () => Buffer.from(token + "\0"),
    },
  });
  return conn;
}

module.exports = dbOps;

