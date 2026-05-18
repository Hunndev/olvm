<!DOCTYPE html>
<!--
  OLVM Site Check — 인쇄용 체크리스트 템플릿

  사용법: Claude가 사이트 정보를 읽어 {{ }} 자리표시자를 치환한 뒤
  ~/.olvm/printouts/{company}-{site}-check-{date}.html 로 저장.

  치환 자리표시자 (Claude가 채움):
    {{COMPANY_ID}}, {{COMPANY_NAME}}
    {{SITE_CODE}}, {{SITE_NAME}}, {{SITE_LOCATION}}
    {{DATE}}, {{VISITOR}}
    {{OLVM_VERSION}}, {{OL_VERSION}}, {{ENGINE_TYPE}}
    {{HOST_TABLE}}            <!-- 호스트 인벤토리 표 행들 -->
    {{NETWORK_INFO}}           <!-- 등록된 네트워크 정보 -->
    {{STORAGE_INFO}}
    {{CONSOLE_URL}}
    {{KNOWN_ISSUES}}
    {{EXTRA_CHECKS}}           <!-- Claude가 frontmatter 기반 자동 생성한 추가 확인 항목 -->
    {{EMERGENCY_CONTACTS}}
-->
<html lang="ko">
<head>
<meta charset="UTF-8">
<title>OLVM 사이트 점검 체크리스트 — {{COMPANY_ID}} / {{SITE_CODE}}</title>
<style>
/* print.css 인라인 임베드 — 외부 의존성 없이 단독 파일로 동작 */
{{PRINT_CSS}}
</style>
</head>
<body>

<div class="print-hint no-print">
  💡 인쇄: 브라우저 메뉴에서 인쇄(Ctrl/Cmd + P) → PDF 저장 또는 직접 인쇄.<br>
  여백/배경 색상 보존을 위해 인쇄 옵션에서 "배경 그래픽" 체크 권장.
</div>

<!-- ============ 1쪽: 표지 / 방문 정보 ============ -->
<h1>OLVM 사이트 점검 체크리스트</h1>

<div class="meta-box">
  <div class="row"><span class="label">회사 / 사이트</span>{{COMPANY_NAME}} / {{SITE_NAME}} ({{COMPANY_ID}}/{{SITE_CODE}})</div>
  <div class="row"><span class="label">위치</span>{{SITE_LOCATION}}</div>
  <div class="row"><span class="label">방문 일자</span>{{DATE}} (___요일)</div>
  <div class="row"><span class="label">방문자(우리)</span><span class="line"></span></div>
  <div class="row"><span class="label">동행자(고객)</span><span class="line"></span></div>
  <div class="row"><span class="label">소요 시간</span>____:____ ~ ____:____</div>
</div>

<h2>도착 시 우선 확인</h2>
<ul class="checklist">
  <li>출입증 수령 / 보안 서약 / 상면 위치 확인</li>
  <li>현장 책임자 미팅, 비상 연락처 재확인</li>
  <li>콘솔/노트북 부팅 + OLVM 웹 콘솔 접근 시도 (결과: □ 정상 □ 느림 □ 불가)</li>
  <li>모든 호스트에서 <code>date</code> 시간 동기 확인 (어긋나면 인증서 오류 발생)</li>
</ul>

<h2>사이트 요약 카드</h2>
<div class="meta-box">
  <div class="row"><span class="label">OLVM 버전</span>{{OLVM_VERSION}}</div>
  <div class="row"><span class="label">OL 버전</span>{{OL_VERSION}}</div>
  <div class="row"><span class="label">Engine 형태</span>{{ENGINE_TYPE}}</div>
  <div class="row"><span class="label">콘솔 URL</span>{{CONSOLE_URL}}</div>
  <div class="row"><span class="label">비상 연락처</span>{{EMERGENCY_CONTACTS}}</div>
</div>

<div class="page-break"></div>

<!-- ============ 2쪽: OLVM 환경 검증 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 2쪽</div>
<h2>2. OLVM 환경 검증</h2>

<p>등록된 정보가 현재와 일치하는지 확인. 변경 있으면 우측 변경란에 표시.</p>

<table>
  <thead><tr><th>항목</th><th>등록 정보</th><th>변경 여부</th><th>새 값</th></tr></thead>
  <tbody>
    <tr><td>OLVM 버전</td><td>{{OLVM_VERSION}}</td><td>□ 동일 □ 변경</td><td></td></tr>
    <tr><td>OL 버전</td><td>{{OL_VERSION}}</td><td>□ 동일 □ 변경</td><td></td></tr>
    <tr><td>Engine 형태</td><td>{{ENGINE_TYPE}}</td><td>□ 동일 □ 변경</td><td></td></tr>
    <tr><td>호스트 수</td><td>등록 수</td><td>□ 동일 □ 변경</td><td></td></tr>
    <tr><td>SHE 호스트 수</td><td>등록 수</td><td>□ 동일 □ 변경</td><td></td></tr>
  </tbody>
</table>

<h3>확인 명령어 결과</h3>

<p><strong>rpm -q ovirt-engine</strong> (Engine 서버에서)</p>
<div class="cmd-result"></div>

<p><strong>cat /etc/oracle-release</strong></p>
<div class="cmd-result"></div>

<p><strong>engine-config -g ConfigVersion</strong></p>
<div class="cmd-result"></div>

<p><strong>hosted-engine --check-deployed</strong> (SHE 환경만)</p>
<div class="cmd-result"></div>

<div class="page-break"></div>

<!-- ============ 3쪽: 호스트 인벤토리 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 3쪽</div>
<h2>3. 호스트 인벤토리</h2>

{{HOST_TABLE}}

<h3>각 호스트 상태 확인 체크</h3>
<ul class="checklist">
  <li>uptime / date / ntpq -p 결과 (시간 동기 정상)</li>
  <li>systemctl status vdsmd libvirtd 결과 (active)</li>
  <li>free -h / df -h (메모리/디스크 여유)</li>
  <li>ip a, cat /proc/net/bonding/bond0 (네트워크/본딩 정상)</li>
  <li>multipath -ll (멀티패스, 해당 시)</li>
  <li>dmesg | tail -50 (최근 커널 메시지 이상 없음)</li>
</ul>

<h3>호스트별 명령어 결과 기록 (필요 항목만)</h3>
<p>호스트명: <span class="line-short"></span> 명령: <span class="line-short"></span></p>
<div class="cmd-result"></div>

<p>호스트명: <span class="line-short"></span> 명령: <span class="line-short"></span></p>
<div class="cmd-result"></div>

<p>호스트명: <span class="line-short"></span> 명령: <span class="line-short"></span></p>
<div class="cmd-result"></div>

<div class="page-break"></div>

<!-- ============ 4쪽: 네트워크 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 4쪽</div>
<h2>4. 네트워크</h2>

{{NETWORK_INFO}}

<h3>확인 사항</h3>
<ul class="checklist">
  <li>호스트 firewalld 상태 (active/inactive 기록)</li>
  <li>외부 방화벽 정책 변경 없음</li>
  <li>DNS / NTP 응답 정상 (nslookup, chronyc sources)</li>
  <li>Bastion 접근 정상</li>
  <li>스위치 포트 LED 정상 (현장 확인)</li>
</ul>

<h3>본딩 / VLAN 상태 결과</h3>
<p>호스트: <span class="line-short"></span></p>
<div class="cmd-result"></div>

<div class="page-break"></div>

<!-- ============ 5쪽: 스토리지 / 인증 / 백업 / 모니터링 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 5쪽</div>
<h2>5. 스토리지</h2>

{{STORAGE_INFO}}

<ul class="checklist">
  <li>vdsm-tool list-domains 결과 (모든 도메인 active)</li>
  <li>마운트 정상 (mount | grep nfs/iscsi)</li>
  <li>SPM 호스트 확인: <span class="line"></span></li>
  <li>각 도메인 여유 용량 임계치 이내</li>
  <li>멀티패스 path 모두 active (multipath -ll)</li>
</ul>

<h2>6. 인증 / 접속</h2>
<ul class="checklist">
  <li>콘솔 URL 접근 정상</li>
  <li>LDAP/AD 로그인 정상 (해당 시)</li>
  <li>Bastion → 호스트 SSH 정상</li>
  <li>관리자 계정 만료/잠금 없음</li>
</ul>

<h2>7. 백업</h2>
<ul class="checklist">
  <li>Engine 백업 작업 정상 동작 (engine-backup --mode=verify)</li>
  <li>백업 파일 저장 위치 디스크 여유</li>
  <li>마지막 복구 테스트 일자: <span class="line"></span></li>
</ul>

<h2>8. 모니터링</h2>
<ul class="checklist">
  <li>모든 호스트 모니터링 등록 확인</li>
  <li>최근 7일 알람 검토</li>
  <li>알림 채널 동작 확인 (테스트 발송)</li>
</ul>

<div class="page-break"></div>

<!-- ============ 6쪽: 추가로 확인하면 좋은 것 (Claude 자동 생성) ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 6쪽</div>
<h2>★ 추가로 확인하면 좋은 것 (이 사이트 맞춤)</h2>

<p style="font-size: 9pt; color: #555;">
※ 사이트 frontmatter (risk_level, last_incident, she_enabled, 알려진 이슈 등) 기반으로
Claude가 자동 생성한 항목.
</p>

{{EXTRA_CHECKS}}

<h3>알려진 이슈 — 이번 방문에서 재확인할 것</h3>
{{KNOWN_ISSUES}}

<div class="page-break"></div>

<!-- ============ 7쪽: 사진 / 메모 / 마무리 ============ -->
<div class="site-tag">{{COMPANY_ID}} / {{SITE_CODE}} — 7쪽</div>
<h2>사진 촬영 체크리스트</h2>
<ul class="checklist">
  <li>랙 정면 / 배면 전경</li>
  <li>각 호스트 라벨/시리얼 클로즈업</li>
  <li>스토리지 장비 라벨</li>
  <li>네트워크 스위치 라벨 (포트 연결도)</li>
  <li>콘솔 화면 (정상 상태)</li>
  <li>OLVM 콘솔 대시보드</li>
</ul>

<h3>사진 파일명 메모</h3>
<table class="empty-rows">
  <thead><tr><th>대상</th><th>파일명 / 메모</th></tr></thead>
  <tbody>
    <tr><td></td><td></td></tr>
    <tr><td></td><td></td></tr>
    <tr><td></td><td></td></tr>
    <tr><td></td><td></td></tr>
    <tr><td></td><td></td></tr>
    <tr><td></td><td></td></tr>
  </tbody>
</table>

<h2>자유 메모</h2>
<div class="memo-box memo-box-full"></div>

<h2>마무리</h2>
<ul class="checklist">
  <li>출입증 반납</li>
  <li>작업 로그 작성 / 고객 사인</li>
  <li>다음 방문 약속 일자: <span class="line"></span></li>
</ul>

<div class="meta-box" style="margin-top: 8mm;">
  <div class="row"><span class="label">방문자 서명</span><span class="line"></span></div>
  <div class="row"><span class="label">고객측 서명</span><span class="line"></span></div>
  <div class="row"><span class="label">종료 시각</span>____:____</div>
</div>

<p style="font-size: 9pt; color: #999; text-align: center; margin-top: 12mm;">
복귀 후: <code>/olvm-survey {{COMPANY_ID}} {{SITE_CODE}}</code> 다시 실행 → 자동으로 결과 입력 모드 진입
</p>

</body>
</html>
