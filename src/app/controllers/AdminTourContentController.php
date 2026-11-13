<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminTourContentModel;
use App\Models\AdminTourModel;
use App\Models\TourRevisionModel;
use finfo;

/**
 * Nội dung tour ở trang quản trị (US07-S5-01, FR-13 – Nguyễn Tuấn Khôi): ảnh (tải lên hoặc dán đường dẫn https),
 * lịch trình, dịch vụ bao gồm / không bao gồm, chính sách hủy theo phiên bản; xóa tour hoặc ngừng hiển thị và hiển thị lại.
 * Ảnh tải lên: JPG / PNG / WebP tối đa 2 MB, lưu ở public/assets/uploads/tours/ với tên ngẫu nhiên (không dùng tên file
 * của người dùng). Xóa ảnh tải lên thì xóa luôn file. Mỗi thao tác được ghi lịch sử (admin_logs, NFR-09).
 * Xóa tour: tour chưa có đơn thì xóa hẳn; đã có đơn thì chuyển "Ngừng hiển thị" để giữ lịch sử đơn;
 * còn đơn đang xử lý thì không xóa được.
 * Khu /host (HostTourContentController): đơn vị tổ chức sửa ảnh, lịch trình, dịch vụ và chính sách hủy của tour
 * của chính mình khi tour đang "Nháp" hoặc "Bị từ chối" (tour đã duyệt sửa qua bản sửa, file 32); xóa / hiển thị lại
 * tour chỉ dành cho quản trị viên. Bản sửa lúc đầu dùng chung file ảnh với tour gốc nên file chỉ bị xóa khi không còn
 * dòng ảnh nào dùng tới (removeUpload()).
 */
class AdminTourContentController extends AdminController
{
    private const MESSAGES = [
        'image_added' => 'Đã thêm ảnh.',
        'image_deleted' => 'Đã xóa ảnh.',
        'cover_set' => 'Đã đặt ảnh bìa.',
        'item_saved' => 'Đã lưu mục lịch trình.',
        'item_deleted' => 'Đã xóa mục lịch trình.',
        'inclusion_added' => 'Đã thêm dịch vụ.',
        'inclusion_deleted' => 'Đã xóa dịch vụ.',
        'policy_added' => 'Đã thêm phiên bản chính sách hủy mới. Đơn đã đặt vẫn giữ phiên bản lúc đặt.',
        'unchanged' => 'Không có thay đổi nào.',
        'archived' => 'Tour đã có đơn nên được chuyển sang "Ngừng hiển thị" (không xóa để giữ lịch sử đơn).',
        'restored' => 'Tour đã chuyển về "Chờ duyệt". Phê duyệt lại để hiển thị cho khách.',
    ];

    private const EMPTY_FORM = [
        'image_url' => '', 'image_alt' => '',
        'item_id' => '', 'item_time' => '', 'item_description' => '', 'item_sort' => '',
        'inclusion_text' => '', 'inclusion_included' => '1',
        'policy_hours' => '', 'policy_percent' => '', 'policy_terms' => '',
    ];

    /** Lỗi procedure (field) → ô trên form. */
    private const FIELD_MAP = [
        'image' => 'image_url', 'alt_text' => 'image_alt',
        'description' => 'item_description', 'sort_order' => 'item_sort',
        'item_text' => 'inclusion_text',
        'free_before_hours' => 'policy_hours', 'refund_percent' => 'policy_percent', 'terms' => 'policy_terms',
    ];

    private const IMAGE_TYPES = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    private const UPLOAD_DIR = 'uploads/tours';

    private AdminTourContentModel $content;

    public function __construct()
    {
        parent::__construct();
        $this->content = new AdminTourContentModel();
    }

    /** GET /admin/tours/{id}/content?edit_item=<mã mục lịch trình> */
    public function index(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $old = self::EMPTY_FORM;
        $editId = self::parseUuid($this->query('edit_item'));
        foreach ($this->content->itinerary((string) $tour['tour_id']) as $item) {
            if ($item['item_id'] === $editId) {
                $old['item_id'] = (string) $item['item_id'];
                $old['item_time'] = $item['start_time'] === null ? '' : substr((string) $item['start_time'], 0, 5);
                $old['item_description'] = (string) $item['description'];
                $old['item_sort'] = (string) $item['sort_order'];
            }
        }

        $this->renderContent($tour, $old, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/tours/{id}/content/images – image_file (tải lên) hoặc image_url (https), image_alt, _csrf */
    public function addImage(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $old = $this->old(['image_url', 'image_alt']);
        if (!$this->csrfValid()) {
            $this->renderContent($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = [];
        if (mb_strlen($old['image_alt']) > AdminTourContentModel::ALT_MAX_LENGTH) {
            $errors['image_alt'] = 'Mô tả ảnh tối đa ' . AdminTourContentModel::ALT_MAX_LENGTH . ' ký tự.';
        }
        $file = $_FILES['image_file'] ?? null;
        $hasFile = is_array($file) && ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE;
        if (!$hasFile) {
            if ($old['image_url'] === '') {
                $errors['image_url'] = 'Chọn ảnh để tải lên hoặc dán đường dẫn ảnh (https://...).';
            } elseif (!self::validImageUrl($old['image_url'])) {
                $errors['image_url'] = 'Đường dẫn ảnh phải bắt đầu bằng https:// và tối đa ' . AdminTourContentModel::ALT_MAX_LENGTH . ' ký tự.';
            }
        }
        if ($errors !== []) {
            $this->renderContent($tour, $old, $errors, '', 422);
            return;
        }

        $url = $old['image_url'];
        $uploaded = null;
        if ($hasFile) {
            [$uploaded, $uploadError] = self::storeUpload($file);
            if ($uploaded === null) {
                $this->renderContent($tour, $old, ['image_file' => (string) $uploadError], '', 422);
                return;
            }
            $url = $uploaded;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->content->addImage($this->actorId(), $tourId, $url, $old['image_alt']);
        if ((string) $row['result'] !== 'ok' && $uploaded !== null) {
            self::removeUpload($uploaded);
        }
        match ((string) $row['result']) {
            'ok' => $this->back($tourId, 'image_added'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            // Đủ ảnh thì form "Thêm ảnh" bị ẩn, nên lỗi hiện ở thông báo đầu trang thay vì gắn với ô ảnh.
            'limit' => $this->renderContent($tour, $old, ['form' => 'Mỗi tour tối đa ' . AdminTourContentModel::IMAGE_MAX . ' ảnh. Xóa bớt ảnh trước khi thêm.'], '', 409),
            default => $this->renderContent($tour, $old, self::fieldError($row['field'] ?? null), '', 422),
        };
    }

    /** POST /admin/tours/{id}/content/images/{imageId}/delete – _csrf */
    public function deleteImage(string $id, string $imageId): void
    {
        $tour = $this->findTourOrFail($id);
        $imageId = self::parseUuid($imageId) ?? self::notFound();
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->content->deleteImage($this->actorId(), $tourId, $imageId);
        if ((string) $row['result'] === 'ok') {
            self::removeUpload((string) ($row['url'] ?? ''));
        }
        $this->afterSimple($tour, (string) $row['result'], 'image_deleted', 'Không tìm thấy ảnh này (có thể đã bị xóa).');
    }

    /** POST /admin/tours/{id}/content/images/{imageId}/cover – _csrf */
    public function setCover(string $id, string $imageId): void
    {
        $tour = $this->findTourOrFail($id);
        $imageId = self::parseUuid($imageId) ?? self::notFound();
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $row = $this->content->setCover($this->actorId(), (string) $tour['tour_id'], $imageId);
        $this->afterSimple($tour, (string) $row['result'], 'cover_set', 'Không tìm thấy ảnh này (có thể đã bị xóa).');
    }

    /** POST /admin/tours/{id}/content/itinerary – item_id ('' = mục mới), item_time (HH:MM, có thể trống), item_description, item_sort, _csrf */
    public function saveItinerary(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $tourId = (string) $tour['tour_id'];
        $old = $this->old(['item_id', 'item_time', 'item_description', 'item_sort']);
        if (!$this->csrfValid()) {
            $this->renderContent($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = [];
        $itemId = $old['item_id'] === '' ? null : self::parseUuid($old['item_id']);
        if ($old['item_id'] !== '' && $itemId === null) {
            $errors['form'] = 'Không tìm thấy mục lịch trình này, vui lòng tải lại trang.';
        }
        $time = null;
        if ($old['item_time'] !== '') {
            if (preg_match('/^([01]\d|2[0-3]):[0-5]\d$/D', $old['item_time']) !== 1) {
                $errors['item_time'] = 'Giờ theo dạng HH:MM, ví dụ 08:30. Để trống nếu mục không ghi giờ.';
            } else {
                $time = $old['item_time'] . ':00';
            }
        }
        $length = mb_strlen($old['item_description']);
        if ($length === 0) {
            $errors['item_description'] = 'Vui lòng nhập nội dung mục lịch trình.';
        } elseif ($length > AdminTourContentModel::ITINERARY_TEXT_MAX_LENGTH) {
            $errors['item_description'] = 'Nội dung tối đa ' . AdminTourContentModel::ITINERARY_TEXT_MAX_LENGTH . ' ký tự.';
        }
        if ($old['item_sort'] === '') {
            $sort = $itemId === null ? count($this->content->itinerary($tourId)) + 1 : 0;
        } else {
            $sort = ctype_digit($old['item_sort']) && strlen($old['item_sort']) <= 3 ? (int) $old['item_sort'] : -1;
        }
        if ($sort < 0 || $sort > AdminTourContentModel::SORT_MAX) {
            $errors['item_sort'] = 'Thứ tự từ 0 đến ' . AdminTourContentModel::SORT_MAX . '.';
        }
        if ($errors !== []) {
            $this->renderContent($tour, $old, $errors, '', 422);
            return;
        }

        $row = $this->content->saveItinerary($this->actorId(), $tourId, $itemId, $time, $old['item_description'], min($sort, AdminTourContentModel::SORT_MAX));
        match ((string) $row['result']) {
            'ok' => $this->back($tourId, 'item_saved'),
            'unchanged' => $this->back($tourId, 'unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => $this->renderContent($tour, $old, ['form' => 'Không tìm thấy mục lịch trình này, vui lòng tải lại trang.'], '', 404),
            'limit' => $this->renderContent($tour, $old, ['item_description' => 'Mỗi tour tối đa ' . AdminTourContentModel::ITINERARY_MAX . ' mục lịch trình.'], '', 409),
            default => $this->renderContent($tour, $old, self::fieldError($row['field'] ?? null), '', 422),
        };
    }

    /** POST /admin/tours/{id}/content/itinerary/{itemId}/delete – _csrf */
    public function deleteItinerary(string $id, string $itemId): void
    {
        $tour = $this->findTourOrFail($id);
        $itemId = self::parseUuid($itemId) ?? self::notFound();
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $row = $this->content->deleteItinerary($this->actorId(), (string) $tour['tour_id'], $itemId);
        $this->afterSimple($tour, (string) $row['result'], 'item_deleted', 'Không tìm thấy mục lịch trình này (có thể đã bị xóa).');
    }

    /** POST /admin/tours/{id}/content/inclusions – inclusion_text, inclusion_included (1 = bao gồm, 0 = không bao gồm), _csrf */
    public function addInclusion(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $old = $this->old(['inclusion_text', 'inclusion_included']);
        $old['inclusion_included'] = $old['inclusion_included'] === '0' ? '0' : '1';
        if (!$this->csrfValid()) {
            $this->renderContent($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $length = mb_strlen($old['inclusion_text']);
        if ($length === 0 || $length > AdminTourContentModel::INCLUSION_TEXT_MAX_LENGTH) {
            $error = $length === 0 ? 'Vui lòng nhập tên dịch vụ.' : 'Tên dịch vụ tối đa ' . AdminTourContentModel::INCLUSION_TEXT_MAX_LENGTH . ' ký tự.';
            $this->renderContent($tour, $old, ['inclusion_text' => $error], '', 422);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->content->addInclusion($this->actorId(), $tourId, $old['inclusion_text'], $old['inclusion_included'] === '1');
        match ((string) $row['result']) {
            'ok' => $this->back($tourId, 'inclusion_added'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'limit' => $this->renderContent($tour, $old, ['inclusion_text' => 'Mỗi tour tối đa ' . AdminTourContentModel::INCLUSION_MAX . ' dịch vụ.'], '', 409),
            default => $this->renderContent($tour, $old, self::fieldError($row['field'] ?? null), '', 422),
        };
    }

    /** POST /admin/tours/{id}/content/inclusions/{inclusionId}/delete – _csrf */
    public function deleteInclusion(string $id, string $inclusionId): void
    {
        $tour = $this->findTourOrFail($id);
        $inclusionId = self::parseUuid($inclusionId) ?? self::notFound();
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $row = $this->content->deleteInclusion($this->actorId(), (string) $tour['tour_id'], $inclusionId);
        $this->afterSimple($tour, (string) $row['result'], 'inclusion_deleted', 'Không tìm thấy dịch vụ này (có thể đã bị xóa).');
    }

    /** POST /admin/tours/{id}/content/policy – policy_hours (trống = không có mốc hủy miễn phí), policy_percent, policy_terms (bắt buộc), _csrf */
    public function addPolicy(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $old = $this->old(['policy_hours', 'policy_percent', 'policy_terms']);
        if (!$this->csrfValid()) {
            $this->renderContent($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = [];
        $hours = null;
        if ($old['policy_hours'] !== '') {
            $hours = ctype_digit($old['policy_hours']) && strlen($old['policy_hours']) <= 3 ? (int) $old['policy_hours'] : -1;
            if ($hours < 0 || $hours > AdminTourContentModel::POLICY_HOURS_MAX) {
                $errors['policy_hours'] = 'Số giờ từ 0 đến ' . AdminTourContentModel::POLICY_HOURS_MAX . '. Để trống nếu không có mốc hủy miễn phí.';
            }
        }
        $percent = ctype_digit($old['policy_percent']) && strlen($old['policy_percent']) <= 3 ? (int) $old['policy_percent'] : -1;
        if ($percent < 0 || $percent > 100) {
            $errors['policy_percent'] = 'Phần trăm hoàn từ 0 đến 100.';
        }
        $termsLength = mb_strlen($old['policy_terms']);
        if ($termsLength === 0) {
            $errors['policy_terms'] = 'Vui lòng nhập nội dung chính sách cho khách.';
        } elseif ($termsLength > AdminTourContentModel::POLICY_TERMS_MAX_LENGTH) {
            $errors['policy_terms'] = 'Nội dung chính sách tối đa ' . AdminTourContentModel::POLICY_TERMS_MAX_LENGTH . ' ký tự.';
        }
        if ($errors !== []) {
            $this->renderContent($tour, $old, $errors, '', 422);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->content->addPolicy($this->actorId(), $tourId, $hours, $percent, $old['policy_terms']);
        match ((string) $row['result']) {
            'ok' => $this->back($tourId, 'policy_added'),
            'unchanged' => $this->back($tourId, 'unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderContent($tour, $old, self::fieldError($row['field'] ?? null), '', 422),
        };
    }

    /** POST /admin/tours/{id}/delete – confirm=1, _csrf */
    public function deleteTour(string $id): void
    {
        $this->adminOnly();
        $tour = $this->findTourOrFail($id);
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }
        if ($this->input('confirm') !== '1') {
            $this->renderContent($tour, self::EMPTY_FORM, ['confirm' => 'Đánh dấu ô xác nhận trước khi xóa tour.'], '', 422);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        // Tour bị xóa hẳn thì ảnh cũng mất: lấy danh sách trước để xóa file đã tải lên (kể cả ảnh của bản sửa đang mở).
        $images = $this->content->images($tourId);
        if (($tour['revision_id'] ?? null) !== null) {
            $images = array_merge($images, $this->content->images((string) $tour['revision_id']));
        }
        $row = $this->content->deleteTour($this->actorId(), $tourId);

        match ((string) $row['result']) {
            'deleted' => $this->afterDeleted($images),
            'archived' => $this->back($tourId, 'archived'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'already_archived' => $this->renderContent($this->findTourOrFail($tourId), self::EMPTY_FORM, ['form' => 'Tour đã ở trạng thái "Ngừng hiển thị".'], '', 409),
            default => $this->renderContent($tour, self::EMPTY_FORM, ['form' => 'Không xóa được: tour còn ' . (int) ($row['active_bookings'] ?? 0)
                . ' đơn đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận. Hãy xử lý hoặc hủy các đơn này ở trang "Yêu cầu đặt tour" trước.'], '', 409),
        };
    }

    /** POST /admin/tours/{id}/restore – _csrf (tour "Ngừng hiển thị" → "Chờ duyệt") */
    public function restoreTour(string $id): void
    {
        $this->adminOnly();
        $tour = $this->findTourOrFail($id);
        if (!$this->csrfValid()) {
            $this->renderContent($tour, self::EMPTY_FORM, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->content->restoreTour($this->actorId(), $tourId);
        match ((string) $row['result']) {
            'ok' => $this->back($tourId, 'restored'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderContent($this->findTourOrFail($tourId), self::EMPTY_FORM, ['form' => 'Chỉ tour đang "Ngừng hiển thị" mới hiển thị lại được.'], '', 409),
        };
    }

    /* ---------- Hỗ trợ ---------- */

    /**
     * @param list<string> $fields
     * @return array<string, string>
     */
    private function old(array $fields): array
    {
        $old = self::EMPTY_FORM;
        foreach ($fields as $field) {
            $old[$field] = $this->input($field);
        }

        return $old;
    }

    private static function validImageUrl(string $url): bool
    {
        return strlen($url) <= AdminTourContentModel::ALT_MAX_LENGTH
            && filter_var($url, FILTER_VALIDATE_URL) !== false
            && str_starts_with(strtolower($url), 'https://');
    }

    /**
     * Lưu ảnh tải lên vào public/assets/uploads/tours/ (tên ngẫu nhiên, đuôi theo nội dung file).
     *
     * @param array<string, mixed> $file phần tử của $_FILES
     * @return array{0: ?string, 1: ?string} [đường dẫn lưu trong CSDL 'uploads/tours/<tên>', lỗi]
     */
    private static function storeUpload(array $file): array
    {
        $error = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        $tooBig = 'Ảnh tối đa ' . (AdminTourContentModel::IMAGE_MAX_BYTES / 1024 / 1024) . ' MB.';
        if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
            return [null, $tooBig];
        }
        $tmp = (string) ($file['tmp_name'] ?? '');
        if ($error !== UPLOAD_ERR_OK || $tmp === '' || !is_uploaded_file($tmp)) {
            return [null, 'Không tải được ảnh lên, vui lòng thử lại.'];
        }
        if ((int) ($file['size'] ?? 0) > AdminTourContentModel::IMAGE_MAX_BYTES || filesize($tmp) > AdminTourContentModel::IMAGE_MAX_BYTES) {
            return [null, $tooBig];
        }

        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($tmp);
        $extension = self::IMAGE_TYPES[$mime] ?? null;
        if ($extension === null || @getimagesize($tmp) === false) {
            return [null, 'Chỉ nhận ảnh JPG, PNG hoặc WebP.'];
        }

        $dir = BASE_PATH . '/public/assets/' . self::UPLOAD_DIR;
        if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
            return [null, 'Chưa lưu được ảnh trên máy chủ, vui lòng thử lại.'];
        }
        $name = bin2hex(random_bytes(16)) . '.' . $extension;
        if (!move_uploaded_file($tmp, $dir . '/' . $name)) {
            return [null, 'Chưa lưu được ảnh trên máy chủ, vui lòng thử lại.'];
        }

        return [self::UPLOAD_DIR . '/' . $name, null];
    }

    /**
     * Xóa file ảnh đã tải lên (chỉ file do trang này tạo: uploads/tours/<32 ký tự hex>.<đuôi>).
     * Gọi sau khi dòng ảnh đã bị xóa: file còn được dòng ảnh khác dùng (tour gốc / bản sửa) thì giữ lại.
     */
    public static function removeUpload(string $url): void
    {
        if (preg_match('#^' . self::UPLOAD_DIR . '/[a-f0-9]{32}\.(jpg|png|webp)$#D', $url) !== 1) {
            return;
        }
        if ((new TourRevisionModel())->imageInUse($url)) {
            return;
        }
        $path = BASE_PATH . '/public/assets/' . $url;
        if (is_file($path)) {
            @unlink($path);
        }
    }

    /** @param list<array<string, mixed>> $images */
    private function afterDeleted(array $images): void
    {
        foreach ($images as $image) {
            self::removeUpload((string) $image['url']);
        }
        $this->redirect('/admin/tours?status=all&msg=deleted');
    }

    /** @param array<string, mixed> $tour */
    private function afterSimple(array $tour, string $result, string $message, string $notFound): void
    {
        match ($result) {
            'ok' => $this->back((string) $tour['tour_id'], $message),
            'unchanged' => $this->back((string) $tour['tour_id'], 'unchanged'),
            'forbidden' => self::forbidden(),
            default => $this->renderContent($tour, self::EMPTY_FORM, ['form' => $notFound], '', 404),
        };
    }

    private function back(string $tourId, string $message): void
    {
        $this->redirect($this->base . '/tours/' . $tourId . '/content?msg=' . $message);
    }

    /** Xóa / hiển thị lại tour: chỉ quản trị viên (khu /host không có đường dẫn này). */
    private function adminOnly(): void
    {
        if ($this->host !== null) {
            self::forbidden();
        }
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $key = self::FIELD_MAP[(string) $field] ?? null;

        return $key !== null
            ? [$key => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findTourOrFail(string $id): array
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : (new AdminTourModel())->find($tourId);
        if ($tour === null) {
            self::notFound();
        }
        $this->authorizeTour((string) $tour['tour_id']);

        return $tour;
    }

    /**
     * @param array<string, mixed> $tour
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderContent(array $tour, array $old, array $errors, string $success, int $status = 200): void
    {
        $tourId = (string) $tour['tour_id'];
        $this->render('admin/tours/content', [
            'title' => 'Nội dung tour · ' . $tour['title'],
            'adminNav' => 'tours',
            'tour' => $tour,
            'images' => $this->content->images($tourId),
            'itinerary' => $this->content->itinerary($tourId),
            'inclusions' => $this->content->inclusions($tourId),
            'policies' => $this->content->policies($tourId),
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
