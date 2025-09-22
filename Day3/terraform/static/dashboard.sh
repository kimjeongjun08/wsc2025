#!/bin/bash
LB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text | sed -E 's/^.*loadbalancer\///')
USER_TG_ARN=$(aws elbv2 describe-target-groups --names apdec-user-tg --query "TargetGroups[].TargetGroupArn" --output text | sed -E 's|^.*targetgroup/|targetgroup/|')
PRODUCT_TG_ARN=$(aws elbv2 describe-target-groups --names apdev-product-tg --query "TargetGroups[].TargetGroupArn" --output text | sed -E 's|^.*targetgroup/|targetgroup/|')
STRESS_TG_ARN=$(aws elbv2 describe-target-groups --names apdev-stress-tg --query "TargetGroups[].TargetGroupArn" --output text | sed -E 's|^.*targetgroup/|targetgroup/|')

cat > dashboard.json <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "apdev-rds-instance", { "period": 60 } ]
                ],
                "region": "ap-northeast-2",
                "title": "RDS CPUUtilization"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", "$LB_ARN", { "region": "ap-northeast-2" } ],
                    [ ".", "HTTPCode_ELB_5XX_Count", ".", ".", { "region": "ap-northeast-2" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "ap-northeast-2",
                "stat": "Sum",
                "period": 60,
                "title": "ALB 응답코드별"
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$LB_ARN", { "region": "ap-northeast-2" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "ap-northeast-2",
                "period": 60,
                "stat": "Sum",
                "title": "ALB RequestCount"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "apdev-rds-instance", { "period": 60 } ]
                ],
                "region": "ap-northeast-2",
                "title": "RDS DatabaseConnections"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "$LB_ARN" ],
                    [ ".", "HTTPCode_Target_4XX_Count", ".", "." ]
                ],
                "region": "ap-northeast-2",
                "title": "Target Group 응답코드별"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", "$USER_TG_ARN", "LoadBalancer", "$LB_ARN", { "region": "ap-northeast-2" } ],
                    [ "...", "$PRODUCT_TG_ARN", ".", ".", { "region": "ap-northeast-2" } ],
                    [ "...", "$STRESS_TG_ARN", ".", ".", { "region": "ap-northeast-2" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "ap-northeast-2",
                "title": "TargetResponse별 Response Time",
                "period": 60,
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ { "id": "blocked", "label": "Blocked", "expression": "SEARCH('{AWS/WAFV2,Rule,WebACL}  Rule=\"ALL\" WebACL=\"main-waf\" MetricName=\"BlockedRequests\" :aws.AccountId = \"LOCAL\"', 'Sum', 60)", "period": 60, "visible": true, "stat": "Sum" } ],
                    [ { "id": "allowed", "label": "Allowed", "expression": "SEARCH('{AWS/WAFV2,Rule,WebACL}  Rule=\"ALL\" WebACL=\"main-waf\" MetricName=\"AllowedRequests\" :aws.AccountId = \"LOCAL\"', 'Sum', 60)", "period": 60, "visible": true, "stat": "Sum" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "liveData": false,
                "title": "WAF Action totals",
                "setPeriodToTimeRange": true,
                "region": "us-east-1",
                "stat": "Sum",
                "period": 60
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "TargetGroup", "$USER_TG_ARN", "LoadBalancer", "$LB_ARN", { "region": "ap-northeast-2" } ],
                    [ "...", "$PRODUCT_TG_ARN", ".", ".", { "region": "ap-northeast-2" } ],
                    [ "...", "$STRESS_TG_ARN", ".", ".", { "region": "ap-northeast-2" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "ap-northeast-2",
                "stat": "Sum",
                "period": 60,
                "title": "TargetGroup RequestCount"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name monitoring-dashboard \
  --dashboard-body file://dashboard.json
