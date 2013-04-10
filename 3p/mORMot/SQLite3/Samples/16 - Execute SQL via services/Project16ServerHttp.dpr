/// this server will use TSQLRestServerFullMemory over HTTP
program Project16ServerHttp;

{.$APPTYPE CONSOLE} // is done below by calling AllocConsole API 

//   first line of uses clause must be   {$I SynDprUses.inc}
uses
  {$I SynDprUses.inc}
  Windows,
  SysUtils,
  Classes,
  SynCommons,
  mORMot,
  mORMotDB,
  mORMotHttpServer,
  SynDB,
  SynDBOracle,
  SynDBSQLite3, SynSQLite3Static,
  SynOleDB,
  SynDBODBC,
  Project16Interface;

type
  TServiceRemoteSQL = class(TInterfacedObject, IRemoteSQL)
  protected
    fProps: TSQLDBConnectionProperties;
  public
    destructor Destroy; override;
  public // implements IRemoteSQL methods
    procedure Connect(aEngine: TRemoteSQLEngine; const aServerName, aDatabaseName,
      aUserID, aPassWord: RawUTF8);
    function GetTableNames: TRawUTF8DynArray;
    function Execute(const aSQL: RawUTF8; aExpectResults, aExpanded: Boolean): RawJSON;
  end;


{ TServiceRemoteSQL }

procedure TServiceRemoteSQL.Connect(aEngine: TRemoteSQLEngine;
  const aServerName, aDatabaseName, aUserID, aPassWord: RawUTF8);
const // rseOleDB, rseODBC, rseOracle, rseSQlite3, rseJet, rseMSSQL
  TYPES: array[TRemoteSQLEngine] of TSQLDBConnectionPropertiesClass = (
     TOleDBConnectionProperties, TODBCConnectionProperties,
     TSQLDBOracleConnectionProperties, TSQLDBSQLite3ConnectionProperties,
     TOleDBJetConnectionProperties, TOleDBMSSQL2008ConnectionProperties);
begin
  if fProps<>nil then
    raise Exception.Create('Connect called more than once');
  fProps := TYPES[aEngine].Create(aServerName,aDatabaseName,aUserID,aPassWord);
end;

function TServiceRemoteSQL.Execute(const aSQL: RawUTF8; aExpectResults, aExpanded: Boolean): RawJSON;
var res: ISQLDBRows;
begin
  if fProps=nil then
    raise Exception.Create('Connect call required before Execute');
  res := fProps.ExecuteInlined(aSQL,aExpectResults);
  if res=nil then
    result := '' else
    result := res.FetchAllAsJSON(aExpanded);
end;

function TServiceRemoteSQL.GetTableNames: TRawUTF8DynArray;
begin
  if fProps=nil then
    raise Exception.Create('Connect call required before GetTableNames');
  fProps.GetTableNames(result);
end;

destructor TServiceRemoteSQL.Destroy;
begin
  FreeAndNil(fProps);
  inherited;
end;


var
  aModel: TSQLModel;
  aServer: TSQLRestServer;
  aHTTPServer: TSQLHttpServer;
begin
  // define the log level
  with TSQLLog.Family do begin
    Level := LOG_VERBOSE;
    EchoToConsole := LOG_VERBOSE; // log all events to the console
  end;
  // manual switch to console mode
  AllocConsole;
  TextColor(ccLightGray);
  // create a Data Model
  aModel := TSQLModel.Create([],ROOT_NAME);
  try
    // initialize a TObjectList-based database engine
    aServer := TSQLRestServerFullMemory.Create(aModel,'users.json',false,true);
    try
      // register our IRemoteSQL service on the server side
      aServer.ServiceRegister(TServiceRemoteSQL,[TypeInfo(IRemoteSQL)],sicClientDriven).
        SetOptions([],[optExecInMainThread]);
      // launch the HTTP server
      aHTTPServer := TSQLHttpServer.Create('888',[aServer]);
      try
        aHTTPServer.AccessControlAllowOrigin := '*'; // for AJAX requests to work
        writeln(#10'Background server is running.'#10);
        writeln('Press [Enter] to close the server.'#10);
        ConsoleWaitForEnterKey;
      finally
        aHTTPServer.Free;
      end;
    finally
      aServer.Free;
    end;
  finally
    aModel.Free;
  end;
end.