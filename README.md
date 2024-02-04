# eks-study

## 목적

## 사전 준비
- 사전환경
    - Computer : mac m1
    - 환경 : Visual Code, Git
- tfenv 설치 및 테라폼 설치
- kubectl 설치
- aws-iam-authenticator
- AWS 사전 준비
    - [x] AWS 계정 생성, MFA 등록, 프로파일 등록
    - [x] ssh key 생성
    - [x] ecr 레포 준비 
- 샘플 앱 코드 빌드
    - [x] backend-app 
        ```
            openjdk-11
        ```
    - [x] frontend-app
        ```
            node v11
            package.json
        ```

## 아키텍처
- 

## To-Do
- [x] 기본 환경 셋팅 
- [x] backend-app 어플리케이션 빌드 및 띄워보기  
- [x] frontend-app 어플리케이션 빌드 및 띄워보기
- [x] batch-app 어플리케이션 빌드 및 띄워보기
- [x] 기본 Nginx 및 Service 구동
- [ ] 기본 Nginx 및 Ingress-Controller 구동
- [ ] karpender 붙여보기 + Spot 인스턴스 연동 및 동작 테스트
- [ ] ebpf 적용 및 networkpolicy 확인
- [ ] istio 동작 확인해보기
- [ ] fargate로 워커 노드 동작시키기
- [ ] request limit 동작 구문 확인하기
- [x] helm 붙여보기
- [ ] 노드 낮은 버전에서 업데이트 시켜보고 동작 확인하기 
- [ ] 모니터링 어떻게 할 것인지
- [ ] 로깅 어떻게 할 것인지
- [ ] 클러스터 보안 요소 검토하기 
- [ ] 인가 구조 및 네임스페이스를 어떻게 나눌 것인지
- [ ] Vault와 연동해보기 
- [ ] 추가 플러그인 제작

## 참고자료
- https://aws.github.io/aws-eks-best-practices/security/docs/
- https://archive.eksworkshop.com/010_introduction/eks/eks_high_architecture/
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/sec-group-reqs.html
- https://www.cloudforecast.io/blog/using-terraform-to-deploy-to-eks/
- https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane/