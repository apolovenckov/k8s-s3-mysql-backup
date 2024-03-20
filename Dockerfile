# Set the base image
FROM alpine:3.6

RUN apk -v --update add \
        python \
        py-pip \
        groff \
        less \
        mailcap \
        mysql-client \
        curl \
        && \
    pip install --upgrade awscli s3cmd python-magic && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*

# Set Default Environment Variables
ENV TARGET_DATABASE_PORT=3306
ENV SLACK_ENABLED=false
ENV SLACK_USERNAME=kubernetes-s3-mysql-backup
ENV TELEGRAM_ENABLED=false

# Copy Slack Alert script and make executable
COPY resources/slack-alert.sh /
RUN chmod +x /slack-alert.sh

# Copy Telegram Alert script and make executable
COPY resources/telegram-notification.sh /
RUN chmod +x /telegram-notification.sh

# Copy backup script and execute
COPY resources/backup.sh /
RUN chmod +x /backup.sh
CMD ["sh", "/backup.sh"]