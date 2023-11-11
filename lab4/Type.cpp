#include "Type.h"
#include <assert.h>
#include <iostream>
#include <sstream>

IntType TypeSystem::commonInt = IntType(4);
VoidType TypeSystem::commonVoid = VoidType();
IntType TypeSystem::commonConstInt = IntType(4, true);

Type *TypeSystem::intType = &commonInt;
Type *TypeSystem::voidType = &commonVoid;
Type *TypeSystem::constIntType = &commonConstInt;

std::string IntType::toStr()
{
    if (constant)
    {
        return "constant int";
    }
    else
    {
        return "int";
    }
}

std::string VoidType::toStr()
{
    return "void";
}

std::string ArrayType::toStr()
{
    std::vector<std::string> vec;
    Type *temp = this;
    while (temp && temp->isArray())
    {
        std::ostringstream buffer;
        if (temp == this && length == 0)                                //遍历数组的维度。循环条件确保 temp 不为空且当前类型是数组类型
            buffer << '[' << ']';
        else
            buffer << '[' << ((ArrayType *)temp)->getLength() << ']';   //如果当前维度有确定的长度，将长度添加到字符串流中
        vec.push_back(buffer.str());                                    //当前维度的字符串表示添加到字符串向量
        temp = ((ArrayType *)temp)->getElementType();                   //temp移动到下一维度的元素类型
        ;
    }
    assert(temp->isInt());
    std::ostringstream buffer;
    if (constant)
        buffer << "const ";
    buffer << "int";
    for (auto it = vec.begin(); it != vec.end(); it++)
        buffer << *it;
    return buffer.str();
}

std::string FunctionType::toStr()
{
    std::ostringstream buffer;
    buffer << returnType->toStr() << "(";
    for (auto it = paramsType.begin(); it != paramsType.end(); it++)//遍历函数的参数类型
     {
        buffer << (*it)->toStr();       //添加到字符流
        if (it + 1 != paramsType.end())
            buffer << ", ";
    }
    buffer << ')';
    return buffer.str();
}

std::string StringType::toStr()
{
    std::ostringstream buffer;
    buffer << "const char[" << length << "]";
    return buffer.str();
}