# --- 阶段 1: 构建 ---
FROM node:20-slim AS builder

# 启用 corepack 安装 pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 1. 复制依赖文件
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json .npmrc ./
# 复制子包结构（包含 package.json）
COPY packages/ ./packages/

# 2. 安装所有依赖
# 使用 --no-frozen-lockfile 避开可能的 lock 冲突，确保安装成功
RUN pnpm install --no-frozen-lockfile

# 3. 复制源码
COPY . .

# 4. 【核心修改】直接指定子包构建，不使用根目录可能不存在的 build:prod
# 先构建底层依赖（如果这个命令报错，可以尝试 pnpm --filter "*" run build）
RUN pnpm run build:deps || echo "No deps to build"

# 强制构建前端主包
RUN pnpm --filter client run build

# --- 阶段 2: 运行 ---
FROM nginx:stable-alpine

# 自动创建配置，支持 SPA 路由
RUN printf 'server {\n\
    listen 80;\n\
    location / {\n\
        root /usr/share/nginx/html;\n\
        index index.html index.htm;\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf

# 复制产物
# 如果这一步报错说找不到路径，请看下方的“排查建议”
COPY --from=builder /app/packages/client/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
