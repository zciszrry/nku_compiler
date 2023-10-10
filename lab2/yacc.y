%{
/*********************************************
YACC file
**********************************************/
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include <string.h>
typedef union {
    int num_val;
    char* str_val;
} YYSTYPE;
int yylex();
extern int yyparse();
extern YYSTYPE yylval;  
FILE* yyin;
void yyerror(const char* s);
void insert(char *name, double value);
int search(char *name);

%}

//TODO:给每个符号定义一个单词类别

%token ADD MINUS          //加减
%token MUL DIV            //乘除
%token Leftpare Rightpare //左右括号
%token <num_val> NUMBER 
%token <str_val> ID       //标识符
%type <num_val> expr lines

%token ASSIGN             //变量声明

                          //优先级
%left ADD MINUS
%left MUL DIV
%right UMINUS         

%%

lines   :       lines expr ';' { printf("\n%d\n", $2); }
        | lines ';'
        |
        ; 
//TODO:完善表达式的规则
expr    :       expr ADD expr   { $$=$1+$3; printf("+");fflush(stdout);}
        |       expr MINUS expr   { $$=$1-$3; printf("-");fflush(stdout);}
        |       expr MUL expr   {$$=$1*$3;printf("*");fflush(stdout);}
        |       expr DIV expr   {$$=$1/$3;printf("/");fflush(stdout);}
        |       ID ASSIGN expr {insert($1,$3);$$=$3;}
        |       ID {$$=search($1);printf("%s",$1);}
        |       MINUS expr %prec UMINUS   {$$=-$2;}
        |       Leftpare expr Rightpare   {$$=$2;}
        |       NUMBER  {$$=$1;printf("%d",$1);fflush(stdout);}
        ;

   

%%

// programs section
#define MAXN 1005
struct{
    char *name;
    int value;
}symtab[MAXN];

int cnt=0;

int search(char *name){
    for(int i=0;i<cnt;i++){
        if(strcmp(symtab[i].name,name)==0){
            return symtab[i].value;
        }
    }
    yyerror("Variable not found");
    return 0;
}   

void insert(char *name,double value){
    for(int i=0;i<cnt;i++){
        if(strcmp(symtab[i].name,name)==0){
            symtab[i].value=value;
            return ;
        }
    }
    if(cnt==MAXN){
        yyerror("Symbol table full");
    }
    symtab[cnt].name=strdup(name);
    symtab[cnt].value=value;
    cnt++;
}

int yylex()
{
    int t;
    int number=0;
    int i;
    while(1){
        t=getchar();
        if(t==' '||t=='\t'||t=='\n'){
            continue;
            //do noting
        }else if(isdigit(t)){
            while(isdigit(t)){
                number = number*10+t-'0';
                t=getchar();
            }
            ungetc(t, stdin); // 把非数字字符放回流中
            yylval.num_val = number;
            number=0;
            return NUMBER;
        }else if(t=='+'){
            return ADD;
        }else if(t=='-'){
            return MINUS;
        }//TODO:识别其他符号
        else if(t=='*'){
            return MUL;
        }
        else if(t=='/'){
            return DIV;
        }
        else if(t=='('){
            return Leftpare;
        }
        else if(t==')'){
            return Rightpare;
        }
        else if(t==' '){
            printf("space!\n");
            continue;
        }
        else if(t=='\n'){
            printf("Enter!\n");
        }
        else if(isalpha(t)||t=='_'){
            char buffer[100];
            int index=0;
            while(isalpha(t)||t=='_'||isdigit(t)){
                buffer[index++]=t;
                t=getchar();
            }
            buffer[index] = '\0';
            ungetc(t, stdin);
            yylval.str_val = strdup(buffer); 
            return ID;
        }
        else if(t=='='){
            return ASSIGN;
        }
        else{
            return t;
        }
    }
}

int main(void)
{
    yyin=stdin;
    do{
        yyparse();
    }while(!feof(yyin));
    return 0;
}
void yyerror(const char* s){
    fprintf(stderr,"Parse error: %s\n",s);
    exit(1);
}
