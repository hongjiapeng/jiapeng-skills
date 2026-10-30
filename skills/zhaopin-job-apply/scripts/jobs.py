"""Generate reviewed Playwright batches and maintain a local application ledger.

Only Python stdlib; no network or browser automation is executed by this helper.
"""
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parent
SUCCESS_TEXT = '已向对方发送简历和打招呼语'
HELD = {'confirmed', 'already_applied', 'unknown'}


def read_json(path):
    data = Path(path).read_bytes()
    if data.startswith((b'\xff\xfe', b'\xfe\xff')):
        text = data.decode('utf-16')
    else:
        text = data.decode('utf-8-sig')
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        marker = re.search(r'^### Result\s*\n', text, re.M)
        if not marker:
            raise ValueError(f'No JSON or CLI Result found in {path}')
        value, _ = json.JSONDecoder().raw_decode(text[marker.end():].lstrip())
        return value


def rows(value):
    if isinstance(value, list):
        return value
    if isinstance(value, dict) and isinstance(value.get('results'), list):
        return value['results']
    raise ValueError('Expected a candidate/result array or an object with results[]')


def key(url):
    parsed = urlsplit(str(url))
    if parsed.scheme not in {'http', 'https'} or parsed.hostname != 'www.zhaopin.com' or not parsed.path.startswith('/jobdetail/'):
        raise ValueError(f'Not an observed Zhaopin job detail URL: {url}')
    match = re.search(r'J\d+', parsed.path)
    return match.group(0) if match else urlunsplit(('https', parsed.netloc.lower(), parsed.path, '', ''))


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def write_new(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8') as handle:
        handle.write(text)


def normalized(raw, origin):
    record = dict(raw)
    record['jobKey'] = key(record['url'])
    record['origin'] = origin
    status = record.get('status', 'unknown')
    if status in {'unknown', '未确认'} and re.search(r'今日投递已超过上限|投递.{0,20}(?:超过|达到).{0,10}上限', str(record.get('evidence', ''))):
        status = 'rate_limited'
    if status in {'已投递', 'confirmed'}:
        evidence = record.get('evidence', '')
        try:
            stamp = datetime.fromisoformat(str(record.get('confirmedAt', '')).replace('Z', '+00:00'))
            dated = stamp.tzinfo is not None
        except ValueError:
            dated = False
        if evidence == SUCCESS_TEXT and dated:
            status = 'confirmed'
        elif origin == 'history':
            status = 'already_applied'
        else:
            status = 'unknown'
    elif status in {'已投递（时间未核实）', '此前已投/已沟通', '未确认'}:
        status = 'unknown'
    elif status == '未投递（当日额度已满）':
        status = 'rate_limited'
    elif status == '未投递（额度弹窗阻挡）':
        status = 'blocked'
    elif status == '操作失败':
        status = 'unknown' if record.get('submitted', True) else 'failed'
    if status not in {'confirmed', 'already_applied', 'unknown', 'rate_limited', 'blocked', 'failed'}:
        raise ValueError(f'Unsupported status: {status}')
    record['status'] = status
    # Old broad english flags are not proof of an actual language requirement.
    if 'languageRequired' not in record:
        record['languageRequired'] = bool(re.search(r'英语|英文|\bEnglish\b', record.get('description', ''), re.I))
        if record.get('english'):
            record['languageReviewNeeded'] = True
    if 'international' not in record:
        record['international'] = bool(re.search(r'海外|跨国|国际化|外企|全球', record.get('description', '')))
    return record


def confirmed(ledger):
    baseline = {r['jobKey'] for r in ledger['records'] if r['origin'] == 'history' and r['status'] in HELD}
    unique = {}
    for record in ledger['records']:
        if record['origin'] == 'current' and record['status'] == 'confirmed' and record['jobKey'] not in baseline:
            unique.setdefault(record['jobKey'], record)
    return list(unique.values())


def stats(ledger):
    success = confirmed(ledger)
    target = ledger.get('target')
    return {'confirmed': len(success), 'target': target,
            'remaining': max(0, target-len(success)) if target is not None else None,
            'explicitLanguage': sum(bool(r.get('languageRequired')) for r in success),
            'international': sum(bool(r.get('international')) for r in success),
            'languageReviewNeeded': sum(bool(r.get('languageReviewNeeded')) for r in success)}


def init(args):
    if Path(args.ledger).exists():
        raise ValueError('Ledger already exists; reuse it, do not reset progress')
    ledger = {'version': 1, 'target': args.target, 'createdAt': datetime.now(timezone.utc).isoformat(), 'records': []}
    for origin, paths in [('history', args.history), ('current', args.current)]:
        for path in paths:
            ledger['records'].extend(normalized(r, origin) for r in rows(read_json(path)) if r.get('url'))
    write_json(args.ledger, ledger)
    return stats(ledger)


def collect(args):
    config = json.dumps({'start': args.start, 'count': args.count})
    template = (ROOT/'collect-template.cjs').read_text(encoding='utf-8')
    write_new(args.out, template.replace('/*CONFIG*/ {}', config))
    return {'output': str(Path(args.out).resolve()), 'start': args.start, 'count': args.count}


def extract(args):
    value = read_json(args.input)
    data = rows(value)
    write_new(args.out, json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    return {'records':len(data), 'stopReason':value.get('stopReason') if isinstance(value, dict) else None}


def plan(args):
    ledger = read_json(args.ledger)
    known = {r['jobKey'] for r in ledger['records'] if r['status'] in HELD}
    candidates = rows(read_json(args.candidates))
    indices = [int(i.strip()) for i in args.indices.split(',') if i.strip()]
    selected = []
    skipped = []
    for index in indices:
        if index < 0 or index >= len(candidates):
            raise ValueError(f'Candidate index out of range: {index}')
        record = candidates[index]
        if any(not record.get(field) for field in ['url','title','company','description']):
            raise ValueError(f'Candidate {index} lacks observed detail; collect it again')
        job_key = key(record['url'])
        if job_key in known:
            skipped.append(index)
            continue
        selected.append(record)
        known.add(job_key)
    remaining = stats(ledger)['remaining']
    if remaining is not None:
        selected = selected[:remaining]
    template = (ROOT/'apply-template.cjs').read_text(encoding='utf-8')
    write_new(args.out, template.replace('/*TARGETS*/ []', json.dumps(selected, ensure_ascii=False)))
    return {'planned':len(selected), 'heldOrDuplicateIndices':skipped, 'output':str(Path(args.out).resolve())}


def merge(args):
    ledger = read_json(args.ledger)
    value = read_json(args.input)
    imported = [normalized(r, 'current') for r in rows(value)]
    def fingerprint(record):
        return hashlib.sha256(json.dumps(record, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    existing = {fingerprint(r) for r in ledger['records']}
    added = 0
    for record in imported:
        identity = fingerprint(record)
        if identity not in existing:
            ledger['records'].append(record)
            existing.add(identity)
            added += 1
    write_json(args.ledger, ledger)
    return {**stats(ledger), 'importedEvents':added,
            'stopReason':value.get('stopReason') if isinstance(value, dict) else None}


def report(args):
    ledger = read_json(args.ledger)
    summary = stats(ledger)
    def cell(text):
        return str(text or '').replace('|', '\\|').replace('\n', ' ')
    progress = f"本轮唯一确认成功：{summary['confirmed']}"
    if summary['target'] is not None:
        progress += f"；目标：{summary['target']}；剩余：{summary['remaining']}"
    lines = ['# 智联投递进度', '', progress+'。', '',
             f"明确语言要求：{summary['explicitLanguage']}；海外/跨国等协作线索：{summary['international']}；旧英语标记待核实：{summary['languageReviewNeeded']}。", '',
             '|序号|公司/发布方|岗位|页面薪资|地点|语言要求|海外线索|', '|---|---|---|---|---|---|---|']
    for index, record in enumerate(confirmed(ledger), 1):
        parts = record.get('summary', '').splitlines()
        salary = parts[1] if len(parts)>1 else record.get('salary', '')
        location = parts[-1] if len(parts)>1 else record.get('city', '')
        title = cell(record['title']).replace('[','\\[').replace(']','\\]')
        link = record['url'].split('?')[0]
        lines.append(f"|{index}|{cell(record['company'])}|[{title}]({link})|{cell(salary)}|{cell(location)}|{'是' if record.get('languageRequired') else '未标记'}|{'是' if record.get('international') else '未标记'}|")
    lines += ['', '## 未计入本轮成功的状态', '', '|公司/发布方|岗位|状态|', '|---|---|---|']
    lines += [f"|{cell(r['company'])}|{cell(r['title'])}|{r['status']}|" for r in ledger['records'] if r['origin']=='current' and r['status']!='confirmed']
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text('\n'.join(lines)+'\n', encoding='utf-8')
    return summary


def positive(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError('Must be positive')
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p=commands.add_parser('init'); p.add_argument('--ledger',required=True); p.add_argument('--target',type=positive); p.add_argument('--history',action='append',default=[]); p.add_argument('--current',action='append',default=[]); p.set_defaults(func=init)
    p=commands.add_parser('collect'); p.add_argument('--start',type=int,default=0); p.add_argument('--count',type=positive,default=10); p.add_argument('--out',required=True); p.set_defaults(func=collect)
    p=commands.add_parser('extract'); p.add_argument('--input',required=True); p.add_argument('--out',required=True); p.set_defaults(func=extract)
    p=commands.add_parser('plan'); p.add_argument('--candidates',required=True); p.add_argument('--indices',required=True); p.add_argument('--ledger',required=True); p.add_argument('--out',required=True); p.set_defaults(func=plan)
    p=commands.add_parser('merge'); p.add_argument('--ledger',required=True); p.add_argument('--input',required=True); p.set_defaults(func=merge)
    p=commands.add_parser('report'); p.add_argument('--ledger',required=True); p.add_argument('--out',required=True); p.set_defaults(func=report)
    args=parser.parse_args()
    if getattr(args, 'start', 0) < 0:
        parser.error('start must be nonnegative')
    try:
        print(json.dumps(args.func(args), ensure_ascii=False))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'Error: {error}\n')


if __name__ == '__main__':
    main()
