"""Build a single-entry Playwright CLI function without shell-interpolating resume text."""

import argparse
import json
from pathlib import Path


def validate_task(task):
    if not isinstance(task, dict):
        raise ValueError('任务必须是JSON对象')
    allowed = {'account_name', 'kind', 'name', 'expected_before', 'text', 'expected_start', 'expected_end'}
    unknown = set(task) - allowed
    if unknown:
        raise ValueError('不支持的任务字段: ' + ', '.join(sorted(unknown)))
    if task.get('kind') not in {'advantage', 'work', 'project'}:
        raise ValueError('kind必须是advantage、work或project')
    required = ['account_name', 'expected_before', 'text']
    if task['kind'] != 'advantage':
        required += ['name', 'expected_start', 'expected_end']
    for key in required:
        if key not in task or not isinstance(task[key], str):
            raise ValueError(f'{key}必须是字符串（不可省略）')
    for key in ('account_name', 'text') + (() if task['kind'] == 'advantage' else ('name',)):
        if not task[key].strip():
            raise ValueError(f'{key}不可为空')
    return task


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', type=Path, help='工作目录中的JSON任务文件')
    parser.add_argument('--out', required=True, type=Path, help='生成的CLI函数文件；必须在技能目录之外')
    parser.add_argument('--force', action='store_true', help='覆盖已有生成文件')
    args = parser.parse_args()
    skill_root = Path(__file__).resolve().parent.parent
    if args.task.resolve().is_relative_to(skill_root) or args.out.resolve().is_relative_to(skill_root):
        parser.error('候选人任务和生成文件必须放在技能目录之外')
    try:
        task = validate_task(json.loads(args.task.read_text(encoding='utf-8-sig')))
        template = Path(__file__).with_name('update_entry.js').read_text(encoding='utf-8')
        if template.count('__RESUME_TASK_JSON__') != 1:
            raise ValueError('函数模板标记数量错误')
        source = template.replace('__RESUME_TASK_JSON__', json.dumps(task, ensure_ascii=True))
        args.out.parent.mkdir(parents=True, exist_ok=True)
        with args.out.open('w' if args.force else 'x', encoding='utf-8', newline='\n') as target:
            target.write(source)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f'已生成单条修改函数: {args.out.resolve()}')
    print('尚未连接浏览器或修改网站。')


if __name__ == '__main__':
    main()
