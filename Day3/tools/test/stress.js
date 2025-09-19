import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// 테스트 설정 - 즉시 VU 적용
export const options = {
  stages: [
    { duration: '0s', target: 30 },     // 즉시 50명으로 시작
    { duration: '5m', target: 30 },     // 2분간 50명 유지
    { duration: '0s', target: 70 },    // 즉시 100명으로 변경
    { duration: '5m', target: 70 },    // 2분간 100명 유지
    { duration: '0s', target: 500 },    // 즉시 200명으로 변경
    { duration: '5m', target: 500 },    // 2분간 200명 유지
    { duration: '0s', target: 100 },    // 즉시 500명으로 변경
    { duration: '5m', target: 100 },    // 2분간 500명 유지
    { duration: '0s', target: 10 },   // 즉시 1000명으로 변경
    { duration: '5m', target: 10 },   // 2분간 1000명 유지
    { duration: '0s', target: 2 },      // 즉시 0명으로 감소
    { duration: '5m', target: 2 },     // 30초간 0명 유지 (정리)
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95%의 요청이 0.2초 이내 완료
    http_req_failed: ['rate<0.1'],     // 에러율 10% 미만
  },
};

// 기본 URL 설정 (환경변수 또는 기본값 사용)
const BASE_URL = __ENV.BASE_URL || 'http://dv7x7l3k87prk.cloudfront.net';

export default function () {
  // UUID 자동 생성
  const uuid = uuidv4();
  
  // requestid 자동 생성 (13자리 숫자)
  const requestid = Math.floor(Math.random() * 9000000000000) + 1000000000000;
  
  // length 값 (256으로 고정)
  const length = 256;
  
  // POST 요청 데이터
  const payload = JSON.stringify({
    requestid: requestid.toString(),
    uuid: uuid,
    length: length
  });

  // POST 요청 헤더
  const headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'curl/8.7.1',
  };

  // POST 요청 URL
  const url = `${BASE_URL}/v1/stress`;

  // POST 요청 실행
  const postResponse = http.post(url, payload, { headers });

  // POST 응답 검증
  check(postResponse, {
    'POST status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'POST response time < 1000ms (SUCCESS)': (r) => r.timings.duration < 1000,
    'POST response time >= 1000ms (SLOW)': (r) => r.timings.duration >= 1000,
    'POST response has correct structure': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body && typeof body === 'object';
      } catch (e) {
        return false;
      }
    },
  });

  // POST 결과 로그 (상태 코드와 응답 시간 모두 고려)
  const postTimeOk = postResponse.timings.duration < 1000;
  const postStatusOk = postResponse.status === 200 || postResponse.status === 201;
  const postTimeStatus = postTimeOk ? 'FAST' : 'SLOW';
  const postOverallStatus = postStatusOk && postTimeOk ? 'SUCCESS' : 'FAIL';
  
  console.log(`STRESS POST: ${requestid} | Status: ${postResponse.status} | Time: ${postResponse.timings.duration}ms | Result: ${postOverallStatus} (${postTimeStatus})`);

  // 요청 간 대기 시간 (0.5-1.5초 랜덤)
  sleep(Math.random() * 1 + 0.5);
}
