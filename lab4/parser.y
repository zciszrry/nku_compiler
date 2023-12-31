// 使用子结点构造父节点，从而构造出整个AST
%code top{
    #include <iostream>
    #include <assert.h>
    #include "parser.h"
    extern Ast ast;
    int yylex();
    int yyerror( char const * );
}

%code requires {
    #include "Ast.h"
    #include "SymbolTable.h"
    #include "Type.h"
}

//属性值可能的取值类型
%union {
    int itype;
    char* strtype;
    StmtNode* stmttype;
    ExprNode* exprtype;
    Type* type;
}

%start Program          //语法分析起始点
%token <strtype> ID     //对应于终结符 ID 的语法树节点的类型是字符串
%token <itype> INTEGER  //对应于 INTEGER 的节点的类型是整数
%token IF ELSE WHILE
%token INT VOID
%token LPAREN RPAREN LBRACE RBRACE SEMICOLON LBRACKET RBRACKET COMMA  
%token ADD SUB MUL DIV MOD OR AND LESS LESSEQUAL GREATER GREATEREQUAL ASSIGN EQUAL NOTEQUAL NOT
%token CONST
%token RETURN BREAK CONTINUE


%nterm <stmttype> Stmts Stmt AssignStmt BlockStmt IfStmt WhileStmt BreakStmt ContinueStmt ReturnStmt DeclStmt FuncDef EmptyStmt FuncDefParams FuncDefParam VarDefs ConstDefs VarDef ConstDef ExprStmt MaybeFuncDefParams
%nterm <exprtype> Exp AddExp MulExp UnaryExp FuncCallExp Cond LOrExp  EqExp PrimaryExp LVal RelExp LAndExp FuncCallParams 
%nterm <type> Type

%precedence THEN
%precedence ELSE   //让else的优先级更高，即else优先与最近的if匹配
%%

//----------------------------编译单元---------------------------
//当解析器成功匹配了 Stmts 规则时要执行的动作

Program
    : Stmts {
        ast.setRoot($1);
    }
    ;

//----------------------------类型---------------------------
//$$ 是规则的结果
//当解析器匹配到 INT 时，$$ 被设置为 TypeSystem::intType，表示这是一个整数类
//当匹配到 VOID 时，$$ 被设置为 TypeSystem::voidType，表示这是一个空类型。

Type
    : INT {
        $$ = TypeSystem::intType;
    }
    | VOID {
        $$ = TypeSystem::voidType;
    }
    ;

//----------------------------语句---------------------------
//Stmts 表示一系列语句，可能只有一条语句（由 Stmt 表示），也可能是多条语句
Stmts
    : Stmt {$$=$1;}
    | Stmts Stmt{
        $$ = new SeqNode($1, $2);
    }
    ;

//Stmt 表示一个语句，可以是赋值语句、块语句、条件语句等等
Stmt
    : AssignStmt {$$=$1;}
    | BlockStmt {$$=$1;}
    | IfStmt {$$=$1;}
    | WhileStmt {$$=$1;}
    | BreakStmt {$$=$1;}
    | ContinueStmt {$$=$1;}
    | ReturnStmt {$$=$1;}
    | DeclStmt {$$=$1;}
    | FuncDef {$$=$1;}
    | EmptyStmt {$$=$1;}
    | ExprStmt {$$=$1;}
    ;
LVal
    : ID {
        SymbolEntry *se;
        //identifiers为一个SymbolTable*类型的外部变量
        //寻找当前域中是否有这个标识符，并返回表项指针，若没有，则语法有问题，报错
        se = identifiers->lookup($1);
        if(se == nullptr)
        {
            // 如果找不到报错
            fprintf(stderr, "identifier \"%s\" is undefined\n", (char*)$1);
            delete [](char*)$1;
            assert(se != nullptr);
        }
        //new了一个ID类的结点，这个类继承自ExprNode
        $$ = new Id(se);
        delete []$1;
    }
    ;

//一个表达式后面跟着一个分号的语句
ExprStmt
    : Exp SEMICOLON {
        $$ = new ExprStmt($1);
    }

//赋值语句，左值（LVal）被赋予右值（Exp）
AssignStmt
    :
    LVal ASSIGN Exp SEMICOLON {
        $$ = new AssignStmt($1, $3);
    }
    ;
BlockStmt  //语句块
    :   LBRACE 
        //每一个块{}都新建一个符号表来保存当前标识符,原有的符号表会由现在符号表的pre指针指向
        {identifiers = new SymbolTable(identifiers);} 
        Stmts RBRACE 
        {
            //每一个{}的作用域里面都是一个复合语句-此处为抽象的非终结符Stmts
            $$ = new CompoundStmt($3);
            //遇到}，当前的块语句结束，删除top符号表
            SymbolTable *top = identifiers;
            identifiers = identifiers->getPrev();
            delete top;
        }
    ;
IfStmt
    //之前已经约定else优先级高于then；产生式的优先级与该产生式最右边的终结符优先级相同
    //%prec THEN的作用是解决悬空-else的二义性问题，他会将终结符THEN的优先级赋给下述产生式
    //这样的话，下述第二个候选式优先级更高（即else优先匹配）
    : IF LPAREN Cond RPAREN Stmt %prec THEN {
        $$ = new IfStmt($3, $5);
    }
    | IF LPAREN Cond RPAREN Stmt ELSE Stmt {
        $$ = new IfElseStmt($3, $5, $7);
    }
    ;
WhileStmt  //While语句
    : WHILE LPAREN Cond RPAREN Stmt {
        $$ = new WhileStmt($3, $5);
    }
    ;
BreakStmt   //Break语句
    : BREAK SEMICOLON {
        $$ = new BreakStmt();
    }
    ;
ContinueStmt   //Continue语句
    : CONTINUE SEMICOLON {
        $$ = new ContinueStmt();
    }
    ;
ReturnStmt    // 返回语句
    :
    RETURN Exp SEMICOLON{
        $$ = new ReturnStmt($2);
    }
    ;
EmptyStmt    //空语句
    : SEMICOLON {
        $$ = new EmptyStmt();
    }
    | LBRACE RBRACE {
        $$=new EmptyStmt();
    }
    ;
Exp   // 算数表达式
    :
    AddExp {$$ = $1;}
    ;
Cond   // 关系+逻辑运算（补）
    :
    LOrExp {$$ = $1;}
    ;

AddExp  // 加减法(双目算数表达式)
    : MulExp {$$ = $1;}
    | AddExp ADD MulExp
    {
        SymbolEntry *se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::ADD, $1, $3);
    }
    | AddExp SUB MulExp
    {
        SymbolEntry *se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::SUB, $1, $3);
    }
    ;

MulExp  // 乘除模(双目算数表达式)
    : UnaryExp {$$ = $1;}
    | MulExp MUL UnaryExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::MUL, $1, $3);
    }
    | MulExp DIV UnaryExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::DIV, $1, $3);
    }
    | MulExp MOD UnaryExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::MOD, $1, $3);
    }
    ;

UnaryExp  //单目运算
    :
    PrimaryExp {$$ = $1;}
    |
    ADD UnaryExp  //'+'号
    {
        SymbolEntry *se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new UnaryExpr(se, UnaryExpr::ADD, $2);
    }
    |
    SUB UnaryExp  //'-'号
    {
        SymbolEntry *se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new UnaryExpr(se, UnaryExpr::SUB, $2);
    }
    |
    NOT UnaryExp  //'!'号
    {
        SymbolEntry *se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new UnaryExpr(se, UnaryExpr::NOT, $2);
    }
    |
    FuncCallExp {$$ = $1;}
    ;

FuncCallExp //函数调用
    : ID LPAREN RPAREN
     {   // 没有参数
        SymbolEntry* se;
        se = identifiers->lookup($1);
        //函数调用前必须要有声明/定义
        if(se == nullptr)
        {
            fprintf(stderr, "function \"%s\" is undefined\n", (char*)$1);
            delete [](char*)$1;
            assert(se != nullptr);
        }
        $$ = new FuncCallExp(se);
    }
    | ID LPAREN FuncCallParams RPAREN
     {   
        SymbolEntry* se;   
        se = identifiers->lookup($1);
        if(se == nullptr)
        {
            fprintf(stderr, "function \"%s\" is undefined\n", (char*)$1);
            delete [](char*)$1;
            assert(se != nullptr);
        }
        $$ = new FuncCallExp(se, $3);
    }
    ;

//函数调用参数列表（实参），参数1，参数2...
FuncCallParams 
    : Exp {$$ = $1;}
    //COMMA为逗号
    | FuncCallParams COMMA Exp {
        $$ = $1;
        $$->setNext($3);
    }
    ;

PrimaryExp  //括号中的表达式、左值和整数常量
    : LPAREN Exp RPAREN {
        $$ = $2;
    }
    | LVal {
        $$ = $1;
    }
    | INTEGER {
        SymbolEntry* se = new ConstantSymbolEntry(TypeSystem::intType, $1);
        $$ = new Constant(se);
    }
    ;

LOrExp
    : LAndExp {$$ = $1;}
    | LOrExp OR LAndExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::OR, $1, $3);
    }
    ;

LAndExp
    : EqExp {$$ = $1;}
    | LAndExp AND EqExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::AND, $1, $3);
    }
    ;

EqExp
    : RelExp {$$ = $1;}
    | EqExp EQUAL RelExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::EQUAL, $1, $3);
    }
    | EqExp NOTEQUAL RelExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::NOTEQUAL, $1, $3);
    }
    ;

RelExp
    : AddExp {$$ = $1;}
    | RelExp LESS AddExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::LESS, $1, $3);
    }
    | RelExp LESSEQUAL AddExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::LESSEQUAL, $1, $3);
    }
    | RelExp GREATER AddExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::GREATER, $1, $3);
    }
    | RelExp GREATEREQUAL AddExp {
        SymbolEntry* se = new TemporarySymbolEntry(TypeSystem::intType, SymbolTable::getLabel());
        $$ = new BinaryExpr(se, BinaryExpr::GREATEREQUAL, $1, $3);
    }
    ;



//----------------------------声明---------------------------
DeclStmt
    :
    //变量声明
    Type VarDefs SEMICOLON {
        $$ = $2;
    }
    |
    //常量声明
    CONST Type ConstDefs SEMICOLON {
        $$ = $3;
    }
    ;
VarDefs
    : VarDefs COMMA VarDef {
        $$ = $1;
        $1->setNext($3); //参数表的参数通过指针串起来
    } 
    | VarDef {$$ = $1;}
    ;
ConstDefs
    : ConstDefs COMMA ConstDef {
        $$ = $1;
        $1->setNext($3);
    }
    | ConstDef {$$ = $1;}
    ;

VarDef
    : ID {   //新创建标识符，和前面的LVAL不同
        SymbolEntry* se;
        se = new IdentifierSymbolEntry(TypeSystem::intType, $1, identifiers->getLevel());
        identifiers->install($1, se);
        $$ = new DeclStmt(new Id(se));
        delete []$1;
    }
    | ID ASSIGN Exp {
        SymbolEntry* se;
        se = new IdentifierSymbolEntry(TypeSystem::intType, $1, identifiers->getLevel());
        identifiers->install($1, se);
        $$ = new DeclStmt(new Id(se), $3);
        delete []$1;
    }
    ;

//常量的声明要求必须赋初值
ConstDef
    : ID ASSIGN Exp {
        SymbolEntry* se;
        se = new IdentifierSymbolEntry(TypeSystem::constIntType, $1, identifiers->getLevel());
        identifiers->install($1, se);
        $$ = new DeclStmt(new Id(se), $3);
        delete []$1;
    }
    ;

FuncDef
    :
    Type ID {
        identifiers = new SymbolTable(identifiers);
    }
    LPAREN MaybeFuncDefParams RPAREN {
        Type* funcType;
        std::vector<Type*> vec;
        DeclStmt* temp = (DeclStmt*)$5;
        // 不断获取参数类型写入vec
        while(temp){
            //从 temp 中获取参数的类型，将其添加到 vec 中
            vec.push_back(temp->getId()->getSymbolEntry()->getType());
            temp = (DeclStmt*)(temp->getNext());
        }
        //使用函数的返回类型 $1 和参数类型的 vector 构造一个 FunctionType 对象，表示函数的整体类型
        funcType = new FunctionType($1, vec);
        //创建一个 SymbolEntry 对象，表示函数名及其类型
        SymbolEntry* se = new IdentifierSymbolEntry(funcType, $2, identifiers->getPrev()->getLevel());
        //该符号表项安装到上一级符号表中
        identifiers->getPrev()->install($2, se);
    } 
    
    //清理函数定义时创建的符号表，并将指针指向上一级符号表
    BlockStmt {
        SymbolEntry* se;
        se = identifiers->lookup($2);
        assert(se != nullptr);
        $$ = new FunctionDef(se, $8, (DeclStmt*)$5);
        SymbolTable* top = identifiers;
        identifiers = identifiers->getPrev();
        delete top;
        delete []$2;
    }
    ;

MaybeFuncDefParams
    : FuncDefParams {$$ = $1;}
    | %empty {$$ = nullptr;}

FuncDefParams
    : FuncDefParams COMMA FuncDefParam {
        $$ = $1;
        $$->setNext($3);
    }
    | FuncDefParam {$$ = $1;}
    ;
    
FuncDefParam
    : Type ID {
        SymbolEntry* se;
        se = new IdentifierSymbolEntry($1, $2, identifiers->getLevel());
        identifiers->install($2, se);
        $$ = new DeclStmt(new Id(se));
        delete []$2;    
    }
    | Type ID ASSIGN Exp {
        SymbolEntry *se;
        se = new IdentifierSymbolEntry($1, $2, identifiers->getLevel());
        identifiers->install($2, se);
        $$ = new DeclStmt(new Id(se),$4);
        delete []$2;
    }
    ;
%%

int yyerror(char const* message)
{
    std::cerr<<message<<std::endl;
    return -1;
}
