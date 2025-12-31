FROM python:3.10-slim

# 1. 安装基础工具、Node.js 20 和常用库
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
# 3. 部署 Gemini 逆向 -> 端口 3000
#    (自动识别是 Python 还是 Node)
# ===========================
WORKDIR /app/gemini
RUN git clone https://github.com/erxiansheng/gemininixiang.git .
# 如果有 requirements.txt 就安装 Python 依赖
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
# 如果有 package.json 就安装 Node 依赖
RUN if [ -f package.json ]; then npm install; fi

# 创建一个智能启动脚本，因为我们不知道入口是哪个文件
RUN echo '#!/bin/bash\n\
if [ -f main.py ]; then\n\
    echo "Starting Python (main.py)..."\n\
    exec python3 main.py\n\
elif [ -f app.py ]; then\n\
    echo "Starting Python (app.py)..."\n\
    exec python3 app.py\n\
elif [ -f package.json ]; then\n\
    echo "Starting Node.js..."\n\
    exec npm start\n\
else\n\
    echo "Error: Could not find startup file (main.py, app.py, or package.json)"\n\
    ls -R\n\
    sleep 3600\n\
fi' > /app/gemini/start.sh && chmod +x /app/gemini/start.sh

# ===========================
# 4. 部署 DeepSeek (Node.js) -> 端口 4000
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN npm install
# 尝试把代码里的 3000 改成 4000，防止端口冲突
RUN grep -rl "3000" . | xargs sed -i 's/3000/4000/g' || true

# ===========================
# 5. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
