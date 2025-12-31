FROM python:3.10-slim

# 1. 安装基础工具、Node.js 20
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# ===========================
# 2. 部署 TTS (Python) -> 端口 5050
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 3. 部署 Gemini -> 端口 3000
# ===========================
WORKDIR /app/gemini
RUN git clone https://github.com/erxiansheng/gemininixiang.git .
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
RUN if [ -f package.json ]; then npm install; fi

# [关键修复] 暴力查找所有文件，把默认的 8000 改为 3000，防止跟 Nginx 冲突
RUN grep -rl "8000" . | xargs sed -i 's/8000/3000/g' || true
RUN grep -rl "8080" . | xargs sed -i 's/8080/3000/g' || true

# 启动脚本
RUN echo '#!/bin/bash\n\
if [ -f main.py ]; then\n\
    echo "Starting Gemini Python..."\n\
    exec python3 main.py\n\
elif [ -f app.py ]; then\n\
    exec python3 app.py\n\
elif [ -f package.json ]; then\n\
    exec npm start\n\
else\n\
    sleep 3600\n\
fi' > start.sh && chmod +x start.sh

# ===========================
# 4. 部署 DeepSeek -> 端口 4000
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
RUN if [ -f package.json ]; then npm install; fi

# [关键修复] 暴力查找所有文件，把默认的 8000 改为 4000
RUN grep -rl "8000" . | xargs sed -i 's/8000/4000/g' || true
RUN grep -rl "3000" . | xargs sed -i 's/3000/4000/g' || true

# 启动脚本
RUN echo '#!/bin/bash\n\
if [ -f main.py ]; then\n\
    echo "Starting DeepSeek Python..."\n\
    exec python3 main.py\n\
elif [ -f app.py ]; then\n\
    exec python3 app.py\n\
elif [ -f package.json ]; then\n\
    exec npm start\n\
else\n\
    sleep 3600\n\
fi' > start.sh && chmod +x start.sh

# ===========================
# 5. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 只有 Nginx 允许监听 8000
ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
