# --- 阶段 1: 构建环境 ---
FROM node:20-slim AS builder

# 启用 corepack 以使用项目指定的 pnpm 版本
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 1. 仅复制依赖定义文件（利用 Docker 缓存层）
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json .npmrc ./
# 复制子包的 package.json
COPY packages/client/package.json ./packages/client/

# 2. 安装依赖 (使用 --frozen-lockfile 确保环境一致性)
RUN pnpm install --frozen-lockfile

# 3. 复制项目所有源代码
COPY . .

# 4. 执行构建
# 根据 README，该项目构建命令为 build:prod，如果报错请改为 pnpm run build
RUN pnpm run build:prod

# --- 阶段 2: 运行环境 (Nginx) ---
FROM nginx:stable-alpine

# 1. 从构建阶段复制静态资源
# 路径根据 packages/client/dist 确定
COPY --from=builder /app/packages/client/dist /usr/share/nginx/html

# 2. 写入 Nginx 配置以支持 SPA (Single Page Application) 路由
# 这能防止刷新页面时出现 404
RUN printf 'server {\n\
    listen 80;\n\
    location / {\n\
        root /usr/share/nginx/html;\n\
        index index.html index.htm;\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
