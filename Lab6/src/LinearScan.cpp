#include "LinearScan.h"
#include <algorithm>
#include <iostream>
#include "LiveVariableAnalysis.h"
#include "MachineCode.h"

LinearScan::LinearScan(MachineUnit *unit)
{
    this->unit = unit;
    for (int i = 4; i < 11; i++)
        regs.push_back(i);
}

void LinearScan::allocateRegisters()
{
    fprintf(stderr, "LinearScan::allocateRegisters()\n");
    for (auto &f : unit->getFuncs())//遍历unit中的所有函数。
    {
        fprintf(stderr, "auto &f : unit->getFuncs(),f:%s\n", f->getSymbol()->toStr().c_str());
        func = f;//将当前函数f赋值给类的成员变量func，以便后续方法可以访问当前函数。
        bool success;
        success = false;//表示尚未成功分配所有虚拟寄存器到实际寄存器
        while (!success) // repeat until all vregs can be mapped
        {
            fprintf(stderr, "computeLiveIntervals in\n");
            computeLiveIntervals();//计算虚拟寄存器的活跃区间
            fprintf(stderr, "computeLiveIntervals out\n");
            success = linearScanRegisterAllocation();//执行线性扫描寄存器分配，尝试将虚拟寄存器映射到实际寄存器。
            fprintf(stderr, "linearScanRegisterAllocation\n");
            if (success)//如果成功（即所有虚拟寄存器都映射到实际寄存器）
            {
                fprintf(stderr, "success \n");
                // all vregs can be mapped to real regs
                modifyCode();//修改代码，将寄存器映射应用到函数的指令中。
                fprintf(stderr, "modifyCode\n");
            }
            else
            {
                fprintf(stderr, "success not\n");
                // spill vregs that can't be mapped to real regs
                genSpillCode();//生成溢出代码，用于将不能映射到实际寄存器的虚拟寄存器进行溢出。
                fprintf(stderr, "genSpillCode\n");
            }
        }
    }
}

void LinearScan::makeDuChains()//创建数据使用链（DU Chains），其中包括每个虚拟寄存器的定义和使用信息
{
    LiveVariableAnalysis lva;
    lva.pass(func);//对当前函数func执行活跃变量分析
    du_chains.clear();//对当前函数func执行活跃变量分析
    int i = 0;
    std::map<MachineOperand, std::set<MachineOperand *>> liveVar;//liveVar为一个从MachineOperand到一组MachineOperand*的映射。
    for (auto &bb : func->getBlocks())//遍历当前函数的基本块
    {
        liveVar.clear();//在每个基本块开始时，清空liveVar，该映射用于跟踪基本块内变量的活跃性。
        for (auto &t : bb->getLiveOut())//遍历基本块的出口的活跃变量。
            liveVar[*t].insert(t);//将活跃变量添加到liveVar映射中
        int no;
        no = i = bb->getInsts().size() + i;
        for (auto inst = bb->getInsts().rbegin(); inst != bb->getInsts().rend(); inst++)
        {
            (*inst)->setNo(no--);//为当前指令设置唯一的编号。
            for (auto &def : (*inst)->getDef())//遍历当前指令的定义。
            {
                if (def->isVReg())//检查定义是否为虚拟寄存器。
                {
                    auto &uses = liveVar[*def];//获取当前定义的虚拟寄存器的使用信息
                    du_chains[def].insert(uses.begin(), uses.end());//将使用信息添加到数据使用链中。
                    auto &kill = lva.getAllUses()[*def];//获取活跃变量分析中定义的虚拟寄存器的使用信息。
                    std::set<MachineOperand *> res;//创建一个集合，用于存储使用信息和定义信息的差集。
                    set_difference(uses.begin(), uses.end(), kill.begin(), kill.end(), inserter(res, res.end()));
                    liveVar[*def] = res;//更新liveVar映射，去除已经被杀死的使用信息。
                }
            }
            for (auto &use : (*inst)->getUse())//遍历当前指令的使用。
            {
                if (use->isVReg())//检查使用是否为虚拟寄存器
                    liveVar[*use].insert(use);//将使用信息添加到liveVar映射中。
            }
        }
    }
}

void LinearScan::computeLiveIntervals()
{
    makeDuChains();
    intervals.clear();
    for (auto &du_chain : du_chains)
    {
        int t = -1;
        for (auto &use : du_chain.second)
            t = std::max(t, use->getParent()->getNo());
        Interval *interval = new Interval({du_chain.first->getParent()->getNo(), t, false, 0, 0, {du_chain.first}, du_chain.second});
        intervals.push_back(interval);
    }
    for (auto &interval : intervals)
    {
        auto uses = interval->uses;
        auto begin = interval->start;
        auto end = interval->end;
        for (auto block : func->getBlocks())
        {
            auto liveIn = block->getLiveIn();
            auto liveOut = block->getLiveOut();
            bool in = false;
            bool out = false;
            for (auto use : uses)
                if (liveIn.count(use))
                {
                    in = true;
                    break;
                }
            for (auto use : uses)
                if (liveOut.count(use))
                {
                    out = true;
                    break;
                }
            if (in && out)
            {
                begin = std::min(begin, (*(block->begin()))->getNo());
                end = std::max(end, (*(block->end()))->getNo());
            }
            else if (!in && out)
            {
                for (auto i : block->getInsts())
                    if (i->getDef().size() > 0 &&
                        i->getDef()[0] == *(uses.begin()))
                    {
                        begin = std::min(begin, i->getNo());
                        break;
                    }
                end = std::max(end, (*(block->end()))->getNo());
            }
            else if (in && !out)
            {
                begin = std::min(begin, (*(block->begin()))->getNo());
                int temp = 0;
                for (auto use : uses)
                    if (use->getParent()->getParent() == block)
                        temp = std::max(temp, use->getParent()->getNo());
                end = std::max(temp, end);
            }
        }
        interval->start = begin;
        interval->end = end;
    }
    bool change;
    change = true;
    while (change)
    {
        change = false;
        std::vector<Interval *> t(intervals.begin(), intervals.end());
        for (size_t i = 0; i < t.size(); i++)
            for (size_t j = i + 1; j < t.size(); j++)
            {
                Interval *w1 = t[i];
                Interval *w2 = t[j];
                if (**w1->defs.begin() == **w2->defs.begin())
                {
                    std::set<MachineOperand *> temp;
                    set_intersection(w1->uses.begin(), w1->uses.end(), w2->uses.begin(), w2->uses.end(), inserter(temp, temp.end()));
                    if (!temp.empty())
                    {
                        change = true;
                        w1->defs.insert(w2->defs.begin(), w2->defs.end());
                        w1->uses.insert(w2->uses.begin(), w2->uses.end());
                        // w1->start = std::min(w1->start, w2->start);
                        // w1->end = std::max(w1->end, w2->end);
                        auto w1Min = std::min(w1->start, w1->end);
                        auto w1Max = std::max(w1->start, w1->end);
                        auto w2Min = std::min(w2->start, w2->end);
                        auto w2Max = std::max(w2->start, w2->end);
                        w1->start = std::min(w1Min, w2Min);
                        w1->end = std::max(w1Max, w2Max);
                        auto it = std::find(intervals.begin(), intervals.end(), w2);
                        if (it != intervals.end())
                            intervals.erase(it);
                    }
                }
            }
    }
    sort(intervals.begin(), intervals.end(), compareStart);
}

bool LinearScan::linearScanRegisterAllocation()
{
    bool success = true;//初始化success为true，表示寄存器分配成功
    active.clear();//清空active集合，该集合用于存储当前活跃的寄存器分配间隔
    regs.clear();//清空regs集合，该集合用于存储可用的物理寄存器
    for (int i = 4; i < 11; i++)//将物理寄存器4到10添加到regs集合中
        regs.push_back(i);
    for (auto &i : intervals)//遍历所有的寄存器分配间隔
    {
        expireOldIntervals(i);//清理过期的寄存器分配间隔
        if (regs.empty())//检查物理寄存器是否用尽
        {
            spillAtInterval(i);//用尽，则溢出当前寄存器分配间隔
            success = false;//将success标记为false，表示寄存器分配失败
        }
        else
        {
            i->rreg = regs.front();//分配物理寄存器给当前间隔
            regs.erase(regs.begin());//从可用寄存器集合中移除已分配的寄存器
            insertToActive(i);//将当前间隔插入活跃寄存器间隔集合中
        }
    }
    return success;
}

void LinearScan::modifyCode()
{
    for (auto &interval : intervals)
    {
        func->addSavedRegs(interval->rreg);
        for (auto def : interval->defs)
            def->setReg(interval->rreg);
        for (auto use : interval->uses)
            use->setReg(interval->rreg);
    }
}

void LinearScan::genSpillCode()
{
    for (auto &interval : intervals)
    {
        if (!interval->spill)
            continue;
        auto cur_func = func;
        MachineInstruction *cur_inst = 0;
        MachineBlock *cur_block;
        int offset = cur_func->AllocSpace(4);
        for (auto use : interval->uses)
        {
            auto reg = new MachineOperand(*use);
            cur_block = use->getParent()->getParent();
            auto useinst = use->getParent();
            cur_inst = new LoadMInstruction(cur_block, reg, new MachineOperand(MachineOperand::REG, 11), new MachineOperand(MachineOperand::IMM, -offset));
            for (auto i = cur_block->getInsts().begin(); i != cur_block->getInsts().end(); i++)
            {
                if (*i == useinst)
                {
                    cur_block->getInsts().insert(i, 1, cur_inst);
                    break;
                }
            }
        }
        for (auto def : interval->defs)
        {
            auto reg = new MachineOperand(*def);
            cur_block = def->getParent()->getParent();
            auto definst = def->getParent();
            cur_inst = new StoreMInstruction(cur_block, reg, new MachineOperand(MachineOperand::REG, 11), new MachineOperand(MachineOperand::IMM, -offset));
            for (auto i = cur_block->getInsts().begin(); i != cur_block->getInsts().end(); i++)
            {
                if (*i == definst)
                {
                    i++;
                    cur_block->getInsts().insert(i, 1, cur_inst);
                    break;
                }
            }
        }
    }
}

void LinearScan::expireOldIntervals(Interval *interval)
{
    auto it = active.begin();
    while (it != active.end())
    {
        if ((*it)->end >= interval->start)
            return;
        regs.push_back((*it)->rreg);
        it = active.erase(find(active.begin(), active.end(), *it));
        sort(regs.begin(), regs.end());
    }
}

void LinearScan::spillAtInterval(Interval *interval)
{
    auto spill = active.back();//从活跃寄存器间隔中获取最后一个间隔，该间隔即将被溢出
    if (spill->end > interval->end)//检查即将被溢出的寄存器间隔的结束位置是否在当前间隔之后
    {                           //如果是，则说明当前间隔需要被溢出
        spill->spill = true;    //标记为溢出
        interval->rreg = spill->rreg;//将即将被溢出的寄存器间隔的寄存器分配给当前间隔
        insertToActive(interval);//将当前间隔插入活跃寄存器间隔集合中
    }
    else
    {
        interval->spill = true;//将当前间隔标记为溢出
    }
}

bool LinearScan::compareStart(Interval *a, Interval *b)
{
    return a->start < b->start;
}

void LinearScan::insertToActive(Interval *handled_interval)
{
    if (active.size() == 0)
    {
        active.push_back(handled_interval);
        return;
    }
    for (auto it = active.begin(); it != active.end(); it++)
    {
        if ((*it)->end > handled_interval->end)
        {
            active.insert(it, 1, handled_interval);
            return;
        }
    }
    active.push_back(handled_interval);
    return;
}