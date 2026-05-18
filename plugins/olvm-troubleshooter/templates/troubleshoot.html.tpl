<!DOCTYPE html>
<!--
  OLVM Troubleshoot Guide — 인쇄용 트러블슈팅 가이드 템플릿

  사용법: Claude가 사용자 증상/가설 + 사이트 정보를 결합해 자리표시자를 치환한 뒤
  ~/.olvm/printouts/{company}-{site}-troubleshoot-{kind}-{date}.html 로 저장.

  자리표시자:
    {{COMPANY_ID}}, {{SITE_CODE}}, {{SITE_NAME}}
    {{DATE}}, {{VISITOR}}, {{TICKET_ID}}
    {{SYMPTOM}}            — 사용자가 보고한 증상 요약
    {{HYPOTHESIS}}         — 사용자 의심 가설 (예: NUMA 의심)
    {{CATEGORY}}            — common-issues.md 의 카테고리 (A~J)
    {{BACKGROUND}}          — Claude의 사전 분석 (사이트 정보 + 도메인 지식)
    {{PRIMARY_CHECKS}}      — 1차 확인 명령어 (안전) + 결과 기록란
    {{HYPOTHESIS_BRANCHES}} — 가설 A/B/C 분기별 체크 포인트
    {{EXTRA_CHECKS}}        — 추가 확인 영역 (사용자가 놓칠 수 있는 곳)
    {{SAFE_ACTIONS}}        — 안전한 조치 (🟢)
    {{CAUTION_ACTIONS}}     — L3 협의 후 조치 (🟡)
    {{FORBIDDEN_ACTIONS}}   — 절대 금지 (🔴)
    {{LOG_LOCATIONS}}       — 봐야 할 로그 위치
    {{EMERGENCY_CONTACTS}}
-->
<html lang="ko">
<head>
<meta charset="UTF-8">
<title>OLVM 트러블슈팅 가이드 — {{COMPANY_ID}} / {{SITE_CODE}}</title>
<style>
{{PRINT_CSS}}
</style>
</head>
<body>

<div class="print-hint no-print">
  💡 인쇄: Ctrl/Cmd + P → "배경 그래픽" 옵션 체크 권장.
</div>

<!-- ============ 1쪽: 표지 / 증상 ============ -->
<h1>OLVM 트러블슈팅 가이드</h1>

<div class="meta-box">
  <div class="row"><span class="label">회사 / 사이트</span>{{COMPANY_ID}} / {{SITE_CODE}} ({{SITE_NAME}})</div>
  <div class="row"><span class="label">티켓/케이스</span>{{TICKET_ID}}</div>
  <div class="row"><span class="label">발급 일자</span>{{DATE}}</div>
  <div class="row"><span class="label">방문자</span>{{VISITOR}}</div>
  <div class="row"><span class="label">카테고리</span>{{CATEGORY}}</div>
</div>

<h2>증상 요약</h2>
<p>{{SYMPTOM}}</p>

<h2>사용자 의심 가설</h2>
<p>{{HYPOTHESIS}}</p>

<h2>현장 도착 시 우선 확인</h2>
<ul class="checklist">
  <li>도착 시각 기록: ____:____</li>
  <li>현재 시점 콘솔 상태 사진 (정상/이상 비교용)</li>
  <li>모든 호스트에서 date 시각 동기 여부 (시간 차이 큰지)</li>
  <li>이번 장애 직전 변경 작업 다시 확인 (고객 청취)</li>
</ul>

<div class="page-break"></div>

<!-- ============ 2쪽: Claude 사전 분석 (배경) ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 2쪽</div>
<h2>배경 — 사이트 환경 + 도메인 분석</h2>

{{BACKGROUND}}

<div class="page-break"></div>

<!-- ============ 3쪽: 1차 확인 (안전 명령어) ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 3쪽</div>
<h2>1차 확인 (안전, 현장 실행 OK)</h2>

<div class="warn-safe">
<span class="tag tag-safe">🟢 안전</span>
다음 명령은 모두 read-only. 시스템에 영향 없음. 결과를 양식에 기록하거나 폰 카메라로 촬영.
</div>

{{PRIMARY_CHECKS}}

<div class="page-break"></div>

<!-- ============ 4쪽: 가설 검증 분기 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 4쪽</div>
<h2>가설별 검증 (사용자 가설 우선)</h2>

<p style="font-size: 10pt; color: #555;">
※ 가설 A가 사용자 의심 가설. 그 가설이 맞는지 먼저 확인한 뒤,
A가 빗나가면 B → C 로 검토 영역 확장.
</p>

{{HYPOTHESIS_BRANCHES}}

<div class="page-break"></div>

<!-- ============ 5쪽: 추가 확인 / 봐야 할 로그 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 5쪽</div>
<h2>추가로 봐주세요 (놓칠 수 있는 곳)</h2>

{{EXTRA_CHECKS}}

<h2>관련 로그 위치</h2>

{{LOG_LOCATIONS}}

<h3>로그 복귀용 압축</h3>
<p>현장에서 로그를 USB 또는 메일로 가져오려면:</p>
<pre style="background:#f5f5f5; padding:2mm; font-size:9pt; border:1px solid #ccc;">
tar czf /tmp/olvm-logs-$(hostname)-$(date +%Y%m%d-%H%M).tar.gz \
  /var/log/vdsm/vdsm.log \
  /var/log/libvirt/libvirtd.log \
  /var/log/libvirt/qemu/*.log \
  /var/log/ovirt-hosted-engine-ha/*.log \
  /var/log/sanlock.log \
  2>/dev/null
ls -lh /tmp/olvm-logs-*.tar.gz
</pre>

<div class="page-break"></div>

<!-- ============ 6쪽: 조치 (위험도별 분류) ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 6쪽</div>
<h2>조치 가이드</h2>

<div class="warn-safe">
<span class="tag tag-safe">🟢 안전한 조치</span><br>
시스템에 영향 적음. 진단/조회 위주. 현장에서 자유롭게 시도 가능.
</div>

{{SAFE_ACTIONS}}

<div class="warn-caution">
<span class="tag tag-caution">🟡 L3/PM 협의 후</span><br>
서비스 영향 가능. 협의 받고 진행. 결과 즉시 확인.
</div>

{{CAUTION_ACTIONS}}

<div class="warn-danger">
<span class="tag tag-danger">🔴 절대 금지</span><br>
데이터 손실 또는 복구 불가 위험. 현장에서 실행 금지.
</div>

{{FORBIDDEN_ACTIONS}}

<div class="page-break"></div>

<!-- ============ 7쪽: 청취 (고객) ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 7쪽</div>
<h2>고객 청취</h2>

<h3>Q1. 장애 발생 시점</h3>
<p>정확한 시각: <span class="line"></span></p>

<h3>Q2. 그 시점 ±24h 변경 작업</h3>
<ul class="checklist">
  <li>OS 패치 / 펌웨어</li>
  <li>OLVM 업데이트</li>
  <li>네트워크 변경 (방화벽, VLAN, 라우팅)</li>
  <li>스토리지 작업 (LUN, 볼륨, 스냅샷)</li>
  <li>백업/복원 작업</li>
  <li>VM 추가/삭제/마이그레이션</li>
  <li>정전 / UPS / 냉각</li>
  <li>기타: <span class="line"></span></li>
</ul>

<h3>Q3. 다른 시스템(AD, DNS, 모니터링)에 같은 시각 이슈?</h3>
<div class="memo-box"></div>

<h3>Q4. 이미 시도한 조치</h3>
<ul class="checklist">
  <li>호스트 재부팅</li>
  <li>VM 재기동</li>
  <li>서비스 재기동</li>
  <li>네트워크 인터페이스 reset</li>
  <li>기타: <span class="line"></span></li>
</ul>
<p>조치 결과:</p>
<div class="memo-box"></div>

<h3>Q5. 비슷한 장애 과거 발생 여부</h3>
<div class="memo-box"></div>

<div class="meta-box" style="margin-top: 8mm;">
  <div class="row"><span class="label">청취 시각</span>____:____</div>
  <div class="row"><span class="label">청취자(우리)</span><span class="line"></span></div>
  <div class="row"><span class="label">답변자(고객)</span><span class="line"></span></div>
</div>

<div class="page-break"></div>

<!-- ============ 8쪽: 종료 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 8쪽</div>
<h2>현장 마무리</h2>

<h3>가져갈 것</h3>
<ul class="checklist">
  <li>채워진 양식 (이 종이)</li>
  <li>로그 파일 (USB 또는 사내망)</li>
  <li>화면 사진 (콘솔, 알람, 로그 출력)</li>
  <li>가능하면 sosreport tar 파일</li>
  <li>고객 사인 (작업 로그)</li>
</ul>

<h3>긴급 연락처</h3>
<div class="meta-box">
{{EMERGENCY_CONTACTS}}
</div>

<h3>결과</h3>
<ul class="checklist">
  <li>현장에서 정상 복귀</li>
  <li>임시 조치 후 추적 필요</li>
  <li>L3 추가 분석 필요 (로그/덤프 회수)</li>
  <li>Oracle Support 케이스 오픈 권고</li>
  <li>고객 보고서 작성 필요</li>
</ul>

<div class="memo-box memo-box-tall"></div>

<div class="meta-box" style="margin-top: 8mm;">
  <div class="row"><span class="label">종료 시각</span>____:____</div>
  <div class="row"><span class="label">방문자 서명</span><span class="line"></span></div>
  <div class="row"><span class="label">고객측 서명</span><span class="line"></span></div>
</div>

<p style="font-size: 9pt; color: #999; text-align: center; margin-top: 12mm;">
복귀 후: <code>/olvm-troubleshoot {{COMPANY_ID}} {{SITE_CODE}}</code> 다시 실행 → 자동으로 결과 입력 모드 진입<br>
입력하면 사이트 .md 의 "알려진 이슈" / "작업 이력" 자동 갱신
</p>

</body>
</html>
