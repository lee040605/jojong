#include <Wire.h>
#include <GY80.h>
#include <Servo.h> // Servo 라이브러리 사용

// GY80 센서 객체 생성
GY80 gy80;

// ESC 객체 생성
Servo escFrontLeft, escFrontRight, escBackLeft, escBackRight;

// ESC 핀 설정
const int ESC_FRONT_LEFT_PIN = 3;
const int ESC_FRONT_RIGHT_PIN = 10;
const int ESC_BACK_LEFT_PIN = 11;
const int ESC_BACK_RIGHT_PIN = 9;

// 기본 ESC 신호 (1000~2000)
int baseThrottle = 2000; // 기본 출력값 (높이 조정 가능)

// PID 제어 변수
float pidRoll, pidPitch;
float errorRoll, errorPitch;
float previousErrorRoll = 0, previousErrorPitch = 0;
float integralRoll = 0, integralPitch = 0;

// PID 상수 (튜닝 필요)
float Kp = 2.0, Ki = 0.02, Kd = 0.1;

void setup() {
  Serial.begin(9600);
  Wire.begin();

  // GY80 센서 초기화
  gy80.begin();
  Serial.println("GY80 initialized.");

  // ESC 초기화
  escFrontLeft.attach(ESC_FRONT_LEFT_PIN);
  escFrontRight.attach(ESC_FRONT_RIGHT_PIN);
  escBackLeft.attach(ESC_BACK_LEFT_PIN);
  escBackRight.attach(ESC_BACK_RIGHT_PIN);

  // 초기 ESC 신호 설정
  initializeESC();
}

void loop() {
  // GY80 센서 데이터 읽기
  GY80_scaled sensorData = gy80.read_scaled();

  // Roll, Pitch 계산
  float roll = atan2(sensorData.a_y, sensorData.a_z) * 180 / PI;
  float pitch = atan2(-sensorData.a_x, sqrt(sensorData.a_y * sensorData.a_y + sensorData.a_z * sensorData.a_z)) * 180 / PI;

  // PID 제어 계산
  errorRoll = -roll;  // 목표 값이 0 (수평 유지)
  errorPitch = -pitch;

  integralRoll += errorRoll;
  integralPitch += errorPitch;

  float derivativeRoll = errorRoll - previousErrorRoll;
  float derivativePitch = errorPitch - previousErrorPitch;

  pidRoll = Kp * errorRoll + Ki * integralRoll + Kd * derivativeRoll;
  pidPitch = Kp * errorPitch + Ki * integralPitch + Kd * derivativePitch;

  previousErrorRoll = errorRoll;
  previousErrorPitch = errorPitch;

  // ESC 신호 계산 (PID 적용)
  int escSignalFrontLeft = baseThrottle + pidPitch + pidRoll;
  int escSignalFrontRight = baseThrottle + pidPitch - pidRoll;
  int escSignalBackLeft = baseThrottle - pidPitch + pidRoll;
  int escSignalBackRight = baseThrottle - pidPitch - pidRoll;

  // ESC 신호 전달
  writeESC(escFrontLeft, escSignalFrontLeft);
  writeESC(escFrontRight, escSignalFrontRight);
  writeESC(escBackLeft, escSignalBackLeft);
  writeESC(escBackRight, escSignalBackRight);

  // 디버깅 출력
  Serial.print("Roll: "); Serial.print(roll);
  Serial.print(", Pitch: "); Serial.print(pitch);
  Serial.print(", Base Throttle: "); Serial.println(baseThrottle);

  delay(20); // 루프 주기
}

void initializeESC() {
  // ESC를 초기화 값으로 설정 (최소 신호)
  writeESC(escFrontLeft, 1000);
  writeESC(escFrontRight, 1000);
  writeESC(escBackLeft, 1000);
  writeESC(escBackRight, 1000);
  delay(3000); // ESC 초기화 대기
}

void writeESC(Servo &esc, int signal) {
  signal = constrain(signal, 1000, 2000); // 신호 제한
  esc.writeMicroseconds(signal); // Servo 객체를 통해 정확한 PWM 신호 전달
}
