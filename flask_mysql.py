from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
import os

# Try to load environment variables from .env file, but don't fail if not found
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = Flask(__name__)

# Use environment variable if available, otherwise use default connection string
database_url = os.getenv('DATABASE_URL', 'mysql+pymysql://minerho:P_ssw0rd@rm-uf6bbjfr09z01wl7jfo.mysql.rds.aliyuncs.com:3306/filelist')

app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = 'your-secret-key-here'  # 用于flash消息
db = SQLAlchemy(app)

@app.route('/', methods=['GET', 'POST'])
def index():
    results = []
    columns = []
    total_count = 0
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 50, type=int)

    # 限制每页显示数量，防止过大值影响性能
    if per_page not in [10, 20, 50, 100, 200]:
        per_page = 50

    # 获取查询参数，优先从 form 获取，否则从 args 获取
    param1 = request.form.get('param1', '') or request.args.get('param1', '')
    param2 = request.form.get('param2', '') or request.args.get('param2', '')

    # 如果有查询参数，执行查询
    if param1 or param2:
        with db.engine.connect() as conn:
            # 首先获取总记录数
            count_sql = text(f"SELECT COUNT(*) FROM myfiles WHERE filename LIKE CONCAT('%', :param1, '%', :param2, '%')")
            total_count = conn.execute(count_sql, {'param1': param1, 'param2': param2}).scalar()

            # 计算总页数
            total_pages = (total_count + per_page - 1) // per_page

            # 添加 LIMIT 和 OFFSET 实现分页
            # 按入库时间倒序（id 自增，越大越新）后再分页
            sql = text(f"SELECT filename FROM myfiles WHERE filename LIKE CONCAT('%', :param1, '%', :param2, '%') ORDER BY id DESC LIMIT :limit OFFSET :offset")
            result = conn.execute(sql, {
                'param1': param1,
                'param2': param2,
                'limit': per_page,
                'offset': (page - 1) * per_page
            })
            columns = result.keys()
            results = [dict(zip(columns, row)) for row in result.fetchall()]

    # 计算总页数
    if param1 or param2:
        total_pages = (total_count + per_page - 1) // per_page
    else:
        total_pages = 1

    # 渲染主页面，使用include方式加载模板
    return render_template('base.html',
                         results=results,
                         columns=columns,
                         page=page,
                         total_pages=total_pages,
                         per_page=per_page,
                         param1=param1,
                         param2=param2,
                         total_count=total_count)

@app.route('/insert', methods=['POST'])
def insert_records():
    try:
        # 获取表单提交的文件名列表
        filenames = request.form.getlist('filenames')
        valid_filenames = [f for f in filenames if f.strip()]

        if not valid_filenames:
            # 检查是否是AJAX请求（通过X-Requested-With头或accept头）
            is_ajax = (request.headers.get('X-Requested-With') == 'XMLHttpRequest' or
                      'application/json' in request.headers.get('Accept', ''))

            if is_ajax:
                return jsonify({
                    'success': False,
                    'message': '没有输入有效的文件名！'
                })
            else:
                flash('没有输入有效的文件名！', 'error')
                return redirect(url_for('index'))

        # 插入记录到数据库
        with db.engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            try:
                inserted_count = 0
                for filename in valid_filenames:
                    sql = text("INSERT INTO myfiles (filename) VALUES (:filename)")
                    conn.execute(sql, {'filename': filename.strip()})
                    inserted_count += 1

                # 提交事务
                trans.commit()
                success_message = f'成功插入 {inserted_count} 条记录！'

                # 检查是否是AJAX请求
                is_ajax = (request.headers.get('X-Requested-With') == 'XMLHttpRequest' or
                          'application/json' in request.headers.get('Accept', ''))

                if is_ajax:
                    return jsonify({
                        'success': True,
                        'message': success_message,
                        'count': inserted_count
                    })
                else:
                    flash(success_message, 'success')

            except Exception as e:
                # 回滚事务
                trans.rollback()
                error_message = f'插入记录失败：{str(e)}'

                # 检查是否是AJAX请求
                is_ajax = (request.headers.get('X-Requested-With') == 'XMLHttpRequest' or
                          'application/json' in request.headers.get('Accept', ''))

                if is_ajax:
                    return jsonify({
                        'success': False,
                        'message': error_message
                    })
                else:
                    flash(error_message, 'error')

    except Exception as e:
        error_message = f'系统错误：{str(e)}'
        # 检查是否是AJAX请求
        is_ajax = (request.headers.get('X-Requested-With') == 'XMLHttpRequest' or
                  'application/json' in request.headers.get('Accept', ''))

        if is_ajax:
            return jsonify({
                'success': False,
                'message': error_message
            })
        else:
            flash(error_message, 'error')

    # 如果不是AJAX请求，重定向到主页
    return redirect(url_for('index'))

@app.route('/delete', methods=['POST'])
def delete_records():
    try:
        # 获取要删除的记录列表（现在是文件名列表）
        data = request.get_json()
        if not data or 'ids' not in data:
            return jsonify({
                'success': False,
                'message': '缺少要删除的记录！'
            })

        filenames = data['ids']
        if not filenames:
            return jsonify({
                'success': False,
                'message': '没有选择要删除的记录！'
            })

        # 确保所有文件名都是字符串且不为空
        valid_filenames = []
        for filename in filenames:
            if filename and isinstance(filename, str) and filename.strip():
                valid_filenames.append(filename.strip())

        if not valid_filenames:
            return jsonify({
                'success': False,
                'message': '没有有效的文件名！'
            })

        # 删除记录（基于文件名）
        with db.engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            try:
                # 构建SQL语句，使用IN子句批量删除
                placeholders = ', '.join([':filename' + str(i) for i in range(len(valid_filenames))])
                params = {'filename' + str(i): valid_filenames[i] for i in range(len(valid_filenames))}

                sql = text(f"DELETE FROM myfiles WHERE filename IN ({placeholders})")
                result = conn.execute(sql, params)
                deleted_count = result.rowcount

                # 提交事务
                trans.commit()
                success_message = f'成功删除 {deleted_count} 条记录！'

                return jsonify({
                    'success': True,
                    'message': success_message,
                    'count': deleted_count
                })

            except Exception as e:
                # 回滚事务
                trans.rollback()
                error_message = f'删除记录失败：{str(e)}'

                return jsonify({
                    'success': False,
                    'message': error_message
                })

    except Exception as e:
        error_message = f'系统错误：{str(e)}'
        return jsonify({
            'success': False,
            'message': error_message
        })

if __name__ == '__main__':
    # Production deployment settings
    port = int(os.environ.get('PORT', 8000))
    # Bind to all interfaces to allow external access
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)