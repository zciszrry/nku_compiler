%option noyywrap
%option nounput
%option noinput
%option yylineno
%top{
    #include<iostream>
    #include<stdio.h>
    #include <stdarg.h>
    #include "common.h"
    #include<string.h>
    using namespace std;
}
%{  
    // 把标识符和符号表项一起存在node中，使用链表维护整个符号表
    struct node{ // 目前暂时只存词素
        char name[3000]={0};
        /* 为符号表项的其他内容准备空间，可直接在此扩展 */
        node* prev=NULL;
        node* next=NULL;
    };

    class SymbolTable{
    public:
        node* head=NULL;
        node* tail=NULL;
        node* insert(char* x);
        node* find(char* x);
        int size();
    };
    int SymbolTable::size(){
        node* curr=head;
        int number=0;
        while(curr!=NULL){
            number++;
            curr=curr->next;
        }
        return number;
    }
    node* SymbolTable::insert(char* x){
        node* p=new node;
        // for(int i=0;x[i]!='\0';i++){
        //     p->name[i]=x[i];
        // }
        strcpy(p->name,x);
        if(head==NULL){// 空链表
            head=tail=p;
            head->next=head;
            head->prev=NULL;
            tail->next=NULL;
            tail->prev=tail;
            return p;
        }
        else if(head==tail){// 一个节点的链表
            head->next=p;
            p->prev=head;
            tail=p;
            return p;
        }
        else{
            tail->next=p;
            p->prev=tail;
            tail=p;
            return p;
        }
    }
    node* SymbolTable::find(char* x){// 如果成功找到就返回节点指针，未成功返回NULL
        node* curr=head;
        while(curr!=NULL){
            if(strcmp(curr->name,x)==0){
                return curr;
            }
            curr=curr->next;
        }
        return NULL;
    }

    extern dump_type_t dump_type;

    int offset=0; /* 用于记录每个token的列号 */

    inline void dump_tokens(const char* format, ...){
        va_list args;
        va_start(args, format);
        if (dump_type == TOKENS)
            vfprintf(yyout, format, args);
        va_end(args);
    }
    SymbolTable symboltable;
%}

/* 定义正则表达式 */
/* 十进制 */
DECIMIAL ([1-9][0-9]*|0)
/* 八进制 */
OCT  0[1-7][0-7]*
/* 十六进制 */
HEX 0(x|X)[1-9a-fA-F][0-9a-fA-F]*|0
/*十进制浮点*/
FLOATING [-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?([fFlL])?
/*十六进制浮点*/
HEXFLOATING (0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)?([pP][-+]?[0-9]+)?)|([0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?)
/*标识符*/
ID [[:alpha:]_][[:alpha:][:digit:]_]*
/* 换行 */
EOL (\r\n|\n|\r)
/*空格*/
WHITE [\t ]

commentBegin "/*"
commentElement .
comment_line(\r\n|\n|\r)
commentEnd "*/"
%x COMMENT

commentLinebegin "//"
commentLineelement .
commentLineend \n
%x COMMENTLINE

    /* 识别到原始的字符串或者识别到某一单词后需要进行的操作 */
%%
    
    /* 保留字 */
    /* 采用直接返回给语法分析器的方式，不放入符号表中 */
"if" {
    dump_tokens("IF\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=2;
}

"else" {
    dump_tokens("ELSE\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=4;
}

"break" {
    dump_tokens("BREAK\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=5;
}

"continue" {
    dump_tokens("CONTINUE\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=8;
}

"const" {
    dump_tokens("CONST\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=5;
}

"while" {
    dump_tokens("WHILE\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=5;
}

"int" {
    dump_tokens("INT\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=3;
}

"float" {
    dump_tokens("FLOAT\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=5;
}

"void" {
    dump_tokens("VOID\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=4;
}

"return" {
    dump_tokens("RETURN\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=6;
}


    /* 比较符 */
">=" {
    dump_tokens("GREATEREQUAL\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=2;
}

"==" {
    dump_tokens("EQUAL\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=2;
}

"<=" {
    dump_tokens("LESSEQUAL\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=2;
}

"!=" {
    dump_tokens("NOTEQUAL\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=2;
}

"=" {
    dump_tokens("ASSIGN\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}

"<" {
    dump_tokens("LESS\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}


    /* 算术运算符 */
"+" {
    dump_tokens("ADD\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}

"-" {
    dump_tokens("SUB\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}

"*" {
    dump_tokens("MUL\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}

"/" {
    dump_tokens("DIV\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}

"%" {
    dump_tokens("MOD\t%s\t%d\t%d\n", yytext,yylineno-1,offset);
    offset+=1;
}


   /* 逻辑运算符 */
"&&" {
    dump_tokens("AND\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=2;
}

"||" {
    dump_tokens("OR\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=2;
}

"!" {
    dump_tokens("NOT\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}


    /* 语句结束符 */
";" {
    dump_tokens("SEMICOLON\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}


    /* 括号 */
"(" {
    dump_tokens("LPAREN\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}

")" {
    dump_tokens("RPAREN\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}

"[" {
    dump_tokens("LBRACKET\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}

"]" {
    dump_tokens("RBRACKET\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}

"{" {
    dump_tokens("LBRACE\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}

"}" {
    dump_tokens("RBRACE\t%s\t%d\t%d\n",yytext,yylineno-1,offset);
    offset+=1;
}


{DECIMIAL} {
    int decimal;
    decimal = atoi(yytext);
    dump_tokens("DECIMAL\t%s\t%d\t%d\t%d\n",yytext,yylineno-1,offset,decimal);
    offset+=yyleng;
}
{OCT}  {
    int oct;
    sscanf(yytext,"%o",&oct);
    dump_tokens("OCT\t%s\t%d\t%d\t%d\n",yytext,yylineno-1,offset,oct);
    offset+=yyleng;
}
{HEX} {
    int hex;
    sscanf(yytext,"%x",&hex);
    dump_tokens("HEX\t%s\t%d\t%d\t%d\n",yytext,yylineno-1,offset,hex);
    offset+=yyleng;
}

{FLOATING} {
    double float_val;
    sscanf(yytext, "%lf", &float_val);
    dump_tokens("FLOATING\t%s\t%d\t%d\t%f\n", yytext, yylineno-1, offset, float_val);
    offset += yyleng;
}

{HEXFLOATING} {
    double float_val = strtod(yytext, NULL);
    dump_tokens("HEXFLOATING\t%s\t%d\t%d\t%f\n", yytext, yylineno, offset, float_val);
    offset += yyleng;
}

{ID} {
    node* p=symboltable.find(yytext);
    if(p==NULL){       
        p=symboltable.insert(yytext);
    }
    dump_tokens("ID\t%s\t%d\t%d\t%p\n", yytext,yylineno-1,offset,p);
    offset+=strlen(yytext);
}

{EOL} {
    /* 重置行内偏移 */
    offset=0;
}

{WHITE} {
    offset++;
}

{commentBegin} {BEGIN COMMENT; }
<COMMENT>{commentElement} {}
<COMMENT>{comment_line} {}
<COMMENT>{commentEnd} {BEGIN INITIAL; }

{commentLinebegin} {BEGIN COMMENTLINE; }
<COMMENTLINE>{commentLineelement} {}
<COMMENTLINE>{commentLineend} {BEGIN INITIAL; }


    /*  Your code here (lab3). */
%%
/* user code section */
